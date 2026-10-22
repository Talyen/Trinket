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
        action.prismaticAffixDamageBonus = QuietAffixRules.prepareAttack(ability: ability, actor: actor, in: &context)
        if context.modifiers(for: actor.id).triggers.firstBurnAttackLeech,
           context.resolution.actionOutcome?.damageKeywords.contains(.burn) == true {
            let isFirstBurnAttack = context.claimTurnGuard(.emberdrinker, actorID: actor.id)
            action.burnAttackLeech = isFirstBurnAttack && context.roster.isBelowHalfHealth(for: actor)
        }
        var operations = ability.operations
        if actor.role == .enemy, ability.dealsCombatDamage {
            action.blindingReduction = context.roster.runtime(for: actor)?.talents.history.blindingReduction ?? 0
            context.roster.mutateRuntime(for: actor) { $0.talents.history.blindingReduction = 0 }
        } else if context.hasHeroCard(for: actor.id) {
            action.goldDamage = context.resolution.cardTalents?.gildedDamage ?? 0
            context.mutateHeroCard { $0.gildedDamage = 0 }
            prepareCardDamage(operations: &operations, actor: actor, in: &context)
            if context.resolution.actionOutcome?.damageKeywords.contains(.freeze) == true,
               context.modifiers(for: actor.id).triggers.steamExplosion {
                let burn = DoTApplicator.consume(.burn, on: context.roster.enemy.combatant, in: &context)
                if burn > 0 {
                    increaseCardDamage(burn, keyword: .freeze, operations: &operations)
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
        preparePoisonAttack(operations: &operations, actor: actor, in: &context)
        context.resolution.prepareActionTalents(action)
        return operations == ability.operations ? ability : ability.replacingOperations(operations)
    }

    private static func captureTalentPreparations(for actor: Combatant, in context: inout BattleState) {
        guard context.hasHeroCard(for: actor.id), let card = context.resolution.cardTalents,
              !card.capturedPreparations, let outcome = context.resolution.cardOutcome(for: actor.id),
              context.roster.participant(for: actor) != nil else { return }
        var eligible: Set<TalentPreparation> = []
        if outcome.damageKeywords.contains(.physical) {
            eligible.formUnion([.bleedDamage, .ignorePhysicalBlock])
        }
        if outcome.damageKeywords.contains(.poison) {
            eligible.insert(.doublePoison)
        }
        var preparations: Set<TalentPreparation> = []
        var goldDamage = 0
        context.roster.mutateRuntime(for: actor) { runtime in
            preparations = runtime.talents.history.preparations.intersection(eligible)
            runtime.talents.history.preparations.subtract(preparations)
            if !outcome.damageKeywords.isEmpty {
                goldDamage = runtime.talents.history.stolenGoldDamage
                runtime.talents.history.stolenGoldDamage = 0
            }
        }
        context.mutateHeroCard {
            $0.capturedPreparations = true
            $0.preparations = preparations
            $0.gildedDamage = goldDamage
        }
    }

    private static func prepareCardDamage(
        operations: inout [AbilityOperation],
        actor: Combatant,
        in context: inout BattleState,
    ) {
        guard let card = context.resolution.cardTalents else { return }
        if card.preparations.contains(.bleedDamage), context.claimHeroCardBonus(.redline, actorID: actor.id) {
            increaseCardDamage(2, keyword: .bleed, operations: &operations)
        }
    }

    private static func preparePoisonAttack(
        operations: inout [AbilityOperation],
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
        guard sealedVial || unstableCulture else { return }
        for index in operations.indices {
            switch operations[index] {
            case let .damage(component) where component.keyword == .poison && component.target != .actor:
                operations[index] = .damage(DamageComponent(
                    SaturatedArithmetic.saturatingMul(component.amount, 2), keyword: .poison, target: component.target,
                    bonusAmount: SaturatedArithmetic.saturatingMul(component.bonusAmount, 2), condition: component.condition,
                    scaling: component.scaling, hasLeech: component.hasLeech,
                ))
            case let .effect(targeted) where targeted.target != .actor:
                let effect: Effect
                switch targeted.effect {
                case let .poison(amount): effect = .poison(SaturatedArithmetic.saturatingMul(amount, 2))
                case let .recurringDamage(.poison, amount, turns):
                    effect = .recurringDamage(.poison, SaturatedArithmetic.saturatingMul(amount, 2), turns)
                default: continue
                }
                operations[index] = .effect(TargetedEffect(
                    effect,
                    target: targeted.target,
                    condition: targeted.condition,
                    chance: targeted.chance,
                ))
            default: continue
            }
        }
    }

    private static func increaseCardDamage(_ amount: Int, keyword: Keyword, operations: inout [AbilityOperation]) {
        if let index = operations.firstIndex(where: {
            guard case let .damage(component) = $0 else { return false }
            return component.keyword == keyword && component.amount > 0 && component.condition == nil
                && (component.target == .abilityTarget || component.target == .enemy)
        }), case let .damage(component) = operations[index] {
            operations[index] = .damage(DamageComponent(
                SaturatedArithmetic.saturatingAdd(component.amount, amount), keyword: keyword, target: component.target,
                bonusAmount: component.bonusAmount,
                condition: component.condition, scaling: component.scaling, hasLeech: component.hasLeech,
            ))
        } else {
            let insertion = operations.lastIndex { $0.damageComponent != nil }.map { $0 + 1 } ?? 0
            operations.insert(.damage(DamageComponent(amount, keyword: keyword)), at: insertion)
        }
    }
}
