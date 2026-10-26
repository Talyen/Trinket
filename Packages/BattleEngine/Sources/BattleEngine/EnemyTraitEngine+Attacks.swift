import TrinketContent
import TrinketCore

extension EnemyTraitEngine {
    struct Attack {
        var burnBonus: Int
        var holyBonus: Int
        var damageReduction: Int
        var reservedReduction: Int
    }

    static func prepareAttack(for actor: Combatant, context: inout BattleState) {
        let triggers = context.enemyModifiers.triggers
        var reduction = context.roster.runtime(for: actor)?.talents.pending.nextDamageReduction ?? 0
        let reserved = reduction
        context.roster.mutateRuntime(for: actor) { $0.talents.pending.nextDamageReduction = 0 }
        if context.roster.isBelowHalfHealth(for: actor) {
            reduction = SaturatedArithmetic.saturatingAdd(reduction, triggers.attackDamageReductionBelowHalf)
        }
        context.resolution.prepareEnemyAttack(Attack(
            burnBonus: triggers.burnAttackDamageBonus,
            holyBonus: triggers.attackHolyBonusVsBelowHalf,
            damageReduction: reduction,
            reservedReduction: reserved,
        ))
    }

    static func applyAttackBonuses(to state: inout DamageResolutionState, context: inout BattleState) {
        guard state.options.isAttackHit, state.amount > 0,
              state.sourceActorID == context.enemy.id, state.combatant.role != .enemy,
              state.provenance == context.resolution.damageProvenance(for: context.enemy.id)
        else { return }
        let belowHalf = context.roster.isBelowHalfHealth(for: state.combatant)
        context.resolution.mutateEnemyAttack(for: context.enemy.id) { attack in
            if state.damageKeyword == .burn {
                state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, attack.burnBonus)
            }
            if belowHalf {
                state.additionalHolyDamage = SaturatedArithmetic.saturatingAdd(state.additionalHolyDamage, attack.holyBonus)
            }
        }
    }

    static func applyAttackReduction(to state: inout DamageResolutionState, context: inout BattleState) {
        guard state.remaining > 0, state.sourceActorID == context.enemy.id, state.combatant.role != .enemy,
              let provenance = state.provenance,
              provenance == context.resolution.damageProvenance(for: context.enemy.id),
              let facts = context.resolution.actionOutcome else { return }
        // Only an attack hit or the initial pulse of its recurring-damage ability
        // spends this budget. Status ticks and retaliation preserve it.
        let initialPulse = state.options.isPeriodic && facts.ability.operations.contains { operation in
            if case let .effect(targeted) = operation, case .recurringDamage = targeted.effect {
                return true
            }
            return false
        }
        guard state.options.isAttackHit || initialPulse else { return }
        var reduction = 0
        context.resolution.mutateEnemyAttack(for: context.enemy.id) { attack in
            reduction = min(state.remaining, attack.damageReduction)
            attack.damageReduction -= reduction
            attack.reservedReduction = max(0, attack.reservedReduction - reduction)
        }
        guard reduction > 0 else { return }
        state.remaining -= reduction
        let profile = context.enemyModifiers
        let trigger: CombatTriggerField = profile.triggers.attackDamageReductionBelowHalf > 0
            ? .attackDamageReductionBelowHalf : .onHealthLossNextDamageReduction
        context.nextEvent(
            kind: .effect(.damageReduced), source: .init(context.enemy),
            abilityName: profile.triggerAbilityName(trigger, fallback: "Loose Rubble"),
            target: state.combatant, amount: reduction, keyword: state.damageKeyword ?? .physical,
        )
    }

    static func applyAttackBleed(from state: CommittedDamage, context: inout BattleState) async {
        let amount = context.enemyModifiers.triggers.attacksApplyBleed
        guard amount > 0, state.options.isAttackHit else { return }
        await DoTApplicator.applyBleed(
            potency: amount, to: state.combatant, sourceActorID: context.enemy.id,
            application: .afterHit, in: &context,
        )
    }

    static func afterAttack(_ facts: ResolvedActionFacts, context: inout BattleState) {
        let actor = facts.action.actor
        guard actor.role == .enemy, !facts.damageKeywords.isEmpty, context.roster.enemy.isAlive else { return }
        var unusedReduction = 0
        context.resolution.mutateEnemyAttack(for: actor.id) { attack in
            unusedReduction = attack.reservedReduction
            attack.reservedReduction = 0
        }
        context.roster.mutateRuntime(for: actor) {
            $0.talents.pending.nextDamageReduction = max($0.talents.pending.nextDamageReduction, unusedReduction)
        }
    }
}
