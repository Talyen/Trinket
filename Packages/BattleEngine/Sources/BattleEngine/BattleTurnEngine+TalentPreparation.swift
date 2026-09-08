import TrinketContent
import TrinketCore

extension BattleTurnEngine {
    static func prepareTalentAction(
        ability: Ability,
        actor: Combatant,
        in context: inout BattleState,
    ) -> Ability {
        captureTalentPreparations(for: actor, in: &context)
        var action = TalentActionFacts(actorID: actor.id)
        var components = ability.damageComponents
        var effects = ability.targetedEffects
        if actor.role == .enemy, ability.dealsCombatDamage {
            action.blindingReduction = context.heroTalents.history[actor.id]?.blindingReduction ?? 0
            context.heroTalents.history[actor.id, default: HeroTalentHistory()].blindingReduction = 0
        } else if context.hasHeroCard(for: actor.id) {
            action.goldDamage = context.heroTalents.cards.last?.gildedDamage ?? 0
            context.mutateHeroCard { $0.gildedDamage = 0 }
            prepareCardDamage(components: &components, effects: &effects, actor: actor, in: &context)
        } else if ability.dealsCombatDamage {
            action.goldDamage = context.heroTalents.history[actor.id]?.stolenGoldDamage ?? 0
            context.heroTalents.history[actor.id, default: HeroTalentHistory()].stolenGoldDamage = 0
            if context.heroTalents.history[actor.id, default: HeroTalentHistory()].preparations.remove(.poisonDamage) != nil {
                increaseCardDamage(2, keyword: .poison, components: &components)
            }
        }
        context.heroTalents.actions.append(action)
        return replacingTalentDamage(in: ability, components: components, effects: effects)
    }

    static func replacingTalentDamage(
        in ability: Ability,
        components: [DamageComponent],
        effects: [TargetedEffect],
    ) -> Ability {
        Ability(
            id: ability.id, name: ability.name, tier: ability.tier,
            description: ability.descriptionOverride,
            damageComponents: components, targetedEffects: effects,
            outcomeBranches: ability.outcomeBranches,
            criticalChanceBonus: ability.criticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: ability.guaranteedCriticalIfEnemyBuffed,
            hasLeech: ability.hasLeech, repeatsManaEmpowerment: ability.repeatsManaEmpowerment,
            stealsGold: ability.stealsGold,
        )
    }

    private static func captureTalentPreparations(for actor: Combatant, in context: inout BattleState) {
        guard context.hasHeroCard(for: actor.id), let card = context.heroTalents.cards.last,
              !card.capturedPreparations else { return }
        var history = context.heroTalents.history[actor.id, default: HeroTalentHistory()]
        var eligible: Set<TalentPreparation> = []
        if !card.damageKeywords.isEmpty {
            eligible.insert(.poisonDamage)
        }
        if card.damageKeywords.contains(.physical) {
            eligible.formUnion([.bleedDamage, .ignorePhysicalBlock, .stealGold])
        }
        if card.damageKeywords.contains(.poison) {
            eligible.insert(.doublePoison)
        }
        let preparations = history.preparations.intersection(eligible)
        history.preparations.subtract(preparations)
        let goldDamage = card.damageKeywords.isEmpty ? 0 : history.stolenGoldDamage
        if !card.damageKeywords.isEmpty {
            history.stolenGoldDamage = 0
        }
        context.heroTalents.history[actor.id] = history
        context.mutateHeroCard {
            $0.capturedPreparations = true
            $0.preparations = preparations
            $0.gildedDamage = goldDamage
        }
    }

    private static func prepareCardDamage(
        components: inout [DamageComponent],
        effects: inout [TargetedEffect],
        actor: Combatant,
        in context: inout BattleState,
    ) {
        guard let card = context.heroTalents.cards.last else { return }
        if card.preparations.contains(.bleedDamage), context.claimHeroCardBonus("redline", actorID: actor.id) {
            increaseCardDamage(2, keyword: .bleed, components: &components)
        }
        if card.preparations.contains(.poisonDamage), context.claimHeroCardBonus("perfectPurity", actorID: actor.id) {
            increaseCardDamage(2, keyword: .poison, components: &components)
        }
        if card.damageKeywords.contains(.poison), context.modifiers(for: actor.id).triggers.sealedVial,
           context.claimHeroCardBonus("sealedVial", actorID: actor.id) {
            let potency = context.roster.activeEffects(for: actor).reduce(0) { sum, active in
                guard case let .poison(amount) = active.effect else { return sum }
                return sum + amount
            }
            if potency > 0 {
                ActiveEffectMutation.removeMatching(from: actor, in: &context) { $0.kind == .poison }
                increaseCardDamage(potency, keyword: .poison, components: &components)
            }
        }
        if card.preparations.contains(.doublePoison), context.claimHeroCardBonus("unstableCulture", actorID: actor.id) {
            components = components.map { component in
                guard component.keyword == .poison, component.target != .actor else { return component }
                return DamageComponent(
                    component.amount * 2, keyword: .poison, target: component.target,
                    bonusAmount: component.bonusAmount * 2, condition: component.condition,
                )
            }
            effects = effects.map { targeted in
                let effect: Effect
                switch targeted.effect {
                case let .poison(amount): effect = .poison(amount * 2)
                case let .recurringDamage(.poison, amount, turns): effect = .recurringDamage(.poison, amount * 2, turns)
                default: return targeted
                }
                guard targeted.target != .actor else { return targeted }
                return TargetedEffect(effect, target: targeted.target, condition: targeted.condition)
            }
        }
    }

    private static func increaseCardDamage(_ amount: Int, keyword: Keyword, components: inout [DamageComponent]) {
        if let index = components.firstIndex(where: {
            $0.keyword == keyword && $0.amount > 0 && $0.condition == nil
                && ($0.target == .abilityTarget || $0.target == .enemy)
        }) {
            let component = components[index]
            components[index] = DamageComponent(
                component.amount + amount, keyword: keyword, target: component.target,
                bonusAmount: component.bonusAmount,
            )
        } else {
            components.append(DamageComponent(amount, keyword: keyword))
        }
    }
}
