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
        if context.modifiers(for: actor.id).triggers.firstBurnAttackLeech,
           context.resolution.actionOutcome?.damageKeywords.contains(.burn) == true {
            action.burnAttackLeech = context.claimTurnGuard(.emberdrinker, actorID: actor.id)
        }
        var components = ability.damageComponents
        var effects = ability.targetedEffects
        if actor.role == .enemy, ability.dealsCombatDamage {
            action.blindingReduction = context.roster.runtime(for: actor)?.talents.history.blindingReduction ?? 0
            context.roster.mutateRuntime(for: actor) { $0.talents.history.blindingReduction = 0 }
        } else if context.hasHeroCard(for: actor.id) {
            action.goldDamage = context.resolution.cardTalents?.gildedDamage ?? 0
            context.mutateHeroCard { $0.gildedDamage = 0 }
            prepareCardDamage(components: &components, actor: actor, in: &context)
            if context.resolution.actionOutcome?.damageKeywords.contains(.freeze) == true,
               context.modifiers(for: actor.id).triggers.steamExplosion {
                let burn = DoTApplicator.consume(.burn, on: context.roster.enemy.combatant, in: &context)
                if burn > 0 {
                    increaseCardDamage(burn, keyword: .freeze, components: &components)
                }
            }
        } else if ability.dealsCombatDamage {
            action.goldDamage = context.roster.runtime(for: actor)?.talents.history.stolenGoldDamage ?? 0
            let isPhysical = context.resolution.actionOutcome?.damageKeywords.contains(.physical) == true
            context.roster.mutateRuntime(for: actor) {
                $0.talents.history.stolenGoldDamage = 0
                if isPhysical {
                    action.ignoresPhysicalBlock = $0.talents.history.preparations.remove(.ignorePhysicalBlock) != nil
                }
            }
        }
        preparePoisonAttack(components: &components, effects: &effects, actor: actor, in: &context)
        context.resolution.prepareActionTalents(action)
        return ability.replacingOperations(preparedOperations(ability, components: components, effects: effects))
    }

    private static func preparedOperations(
        _ ability: Ability, components: [DamageComponent], effects: [TargetedEffect],
    ) -> [AbilityOperation] {
        let originalDamageCount = ability.damageComponents.count
        var result = originalDamageCount == 0 ? components.map(AbilityOperation.damage) : []
        var damageIndex = 0
        var effectIndex = 0
        for operation in ability.operations {
            switch operation {
            case .damage:
                result.append(.damage(components[damageIndex]))
                damageIndex += 1
                if damageIndex == originalDamageCount {
                    result.append(contentsOf: components.dropFirst(originalDamageCount).map(AbilityOperation.damage))
                }
            case .effect:
                result.append(.effect(effects[effectIndex]))
                effectIndex += 1
            }
        }
        return result
    }

    private static func captureTalentPreparations(for actor: Combatant, in context: inout BattleState) {
        guard context.hasHeroCard(for: actor.id), let card = context.resolution.cardTalents,
              !card.capturedPreparations, let outcome = context.resolution.cardOutcome(for: actor.id) else { return }
        guard var history = context.roster.runtime(for: actor)?.talents.history else { return }
        var eligible: Set<TalentPreparation> = []
        if outcome.damageKeywords.contains(.physical) {
            eligible.formUnion([.bleedDamage, .ignorePhysicalBlock])
        }
        if outcome.damageKeywords.contains(.poison) {
            eligible.insert(.doublePoison)
        }
        let preparations = history.preparations.intersection(eligible)
        history.preparations.subtract(preparations)
        let goldDamage = outcome.damageKeywords.isEmpty ? 0 : history.stolenGoldDamage
        if !outcome.damageKeywords.isEmpty {
            history.stolenGoldDamage = 0
        }
        context.roster.mutateRuntime(for: actor) { $0.talents.history = history }
        context.mutateHeroCard {
            $0.capturedPreparations = true
            $0.preparations = preparations
            $0.gildedDamage = goldDamage
        }
    }

    private static func prepareCardDamage(
        components: inout [DamageComponent],
        actor: Combatant,
        in context: inout BattleState,
    ) {
        guard let card = context.resolution.cardTalents else { return }
        if card.preparations.contains(.bleedDamage), context.claimHeroCardBonus(.redline, actorID: actor.id) {
            increaseCardDamage(2, keyword: .bleed, components: &components)
        }
    }

    private static func preparePoisonAttack(
        components: inout [DamageComponent],
        effects: inout [TargetedEffect],
        actor: Combatant,
        in context: inout BattleState,
    ) {
        guard actor.role != .enemy, context.allowsHeroTalentReaction,
              context.resolution.actionOutcome?.damageKeywords.contains(.poison) == true else { return }
        let sealedVial = context.modifiers(for: actor.id).triggers.sealedVial
            && context.claimHeroTalent(.sealedVial, actorID: actor.id, battle: true)
        let unstableCulture: Bool
        if context.hasHeroCard(for: actor.id) {
            unstableCulture = context.resolution.cardTalents?.preparations.contains(.doublePoison) == true
                && context.claimHeroCardBonus(.unstableCulture, actorID: actor.id)
        } else {
            unstableCulture = context.roster.runtime(for: actor)?.talents.history.preparations.contains(.doublePoison) == true
            if unstableCulture {
                context.roster.mutateRuntime(for: actor) { $0.talents.history.preparations.remove(.doublePoison) }
            }
        }
        if sealedVial || unstableCulture {
            components = components.map { component in
                guard component.keyword == .poison, component.target != .actor else { return component }
                return DamageComponent(
                    SaturatedArithmetic.saturatingMul(component.amount, 2), keyword: .poison, target: component.target,
                    bonusAmount: SaturatedArithmetic.saturatingMul(component.bonusAmount, 2), condition: component.condition,
                )
            }
            effects = effects.map { targeted in
                let effect: Effect
                switch targeted.effect {
                case let .poison(amount): effect = .poison(SaturatedArithmetic.saturatingMul(amount, 2))
                case let .recurringDamage(.poison, amount, turns): effect = .recurringDamage(
                        .poison,
                        SaturatedArithmetic.saturatingMul(amount, 2),
                        turns,
                    )
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
                SaturatedArithmetic.saturatingAdd(component.amount, amount), keyword: keyword, target: component.target,
                bonusAmount: component.bonusAmount,
            )
        } else {
            components.append(DamageComponent(amount, keyword: keyword))
        }
    }
}
