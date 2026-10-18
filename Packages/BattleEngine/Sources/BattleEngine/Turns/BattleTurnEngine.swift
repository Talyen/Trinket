import Foundation
import TrinketContent
import TrinketCore

package enum BattleTurnEngine {
    package static func consumeActionSkip(
        for actor: Combatant,
        context: inout BattleState,
    ) async {
        var keyword: Keyword?
        var recovered = false

        context.roster.mutateRuntime(for: actor) { runtime in
            guard let index = runtime.activeEffects.firstIndex(where: \.isAwaitingActionSkip) else { return }
            var effect = runtime.activeEffects[index]
            keyword = effect.keyword
            let extraSkips = context.additionalControlSkipsByEffectID[effect.id, default: 0]
            if extraSkips > 0 {
                context.additionalControlSkipsByEffectID[effect.id] = extraSkips > 1 ? extraSkips - 1 : nil
                effect.remainingTurns = 0
            } else {
                effect.remainingTurns = BattleTiming.controlStatusLingerTurns
                recovered = true
            }
            runtime.activeEffects[index] = effect
        }

        guard let keyword else {
            recordAction(for: actor, context: &context)
            return
        }

        context.nextEvent(
            kind: .effect(.controlActionSkipped),
            source: .init(actorID: nil, name: keyword.statusName),
            abilityName: keyword.statusName,
            target: actor,
            amount: 0,
            keyword: keyword,
        )

        if keyword == .stun, recovered {
            applyStunRecoveryReduction(for: actor, context: &context)
        }
        if actor.role == .enemy, keyword == .stun, recovered {
            if CombatCheckpoint.controlRecovery(actor.id, .stun).allowsContinuation(in: context) {
                await CombatTriggerEngine.afterEnemyStunRecover(in: &context)
            }
        }

        recordAction(for: actor, context: &context)
    }

    private static func applyStunRecoveryReduction(for actor: Combatant, context: inout BattleState) {
        var multiplier = 1.0
        var sourceID: String?
        let opponents = BattleActionContext(actor: actor, in: context).opponents(in: context)
        for opponent in opponents where context.roster.runtime(for: opponent)?.isAlive == true {
            let m = context.modifiers(for: opponent.id).triggers.stunnedEnemyNextTurnDamageMultiplier
            if m < 1 {
                multiplier *= m
                if sourceID == nil {
                    sourceID = opponent.id
                }
            }
        }
        guard multiplier < 1, let sourceID else { return }
        // Round expiry follows this skipped action; retain the reduction through the recovery turn.
        context.insertEffect(.damageReductionPercent(1 - multiplier, 2), to: actor, sourceID: sourceID, remainingTurns: 2)
    }

    package static func performAction(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        origin: DamageOperation.AttackOrigin = .ability,
        context: inout BattleState,
    ) async {
        _ = await resolveAction(
            ability: ability,
            actor: actor,
            abilityTarget: abilityTarget,
            origin: origin,
            entry: .ordinary,
            context: &context,
        )
    }

    /// Synchronous action entry for consumers such as actor-isolated feedback
    /// tests. Construct the executor body here, outside the caller's actor.
    package static func performAction(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        origin: DamageOperation.AttackOrigin = .ability,
        context: inout BattleState,
    ) {
        CombatExecutor.run {
            await performAction(ability: ability, actor: actor, abilityTarget: abilityTarget, origin: origin, context: &context)
        }
    }

    static func performEnemyAction(
        ability: Ability, abilityTarget: Combatant, context: inout BattleState,
    ) async -> Bool {
        await resolveAction(
            ability: ability,
            actor: context.enemy,
            abilityTarget: abilityTarget,
            origin: .ability,
            entry: .enemyTurn,
            context: &context,
        )
    }

    private enum ActionEntry {
        case ordinary, enemyTurn
    }

    private static func resolveAction(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        origin: DamageOperation.AttackOrigin,
        entry: ActionEntry,
        context: inout BattleState,
    ) async -> Bool {
        let action = BattleActionContext(actor: actor, selectedTarget: abilityTarget)
        guard !context.isBattleOver, action.canContinue(in: context) else { return false }
        let previousFeedbackGroup = context.resolution.beginFeedbackGroup(eventID: context.nextEventID + 1)
        defer { context.resolution.feedbackGroupID = previousFeedbackGroup }
        let actionID = context.resolution.beginAction(action, origin: origin)
        defer { context.resolution.endAction() }

        guard BattleAbilityRules.canPayHealthCost(ability, action: action, in: context) else {
            if actor.role == .enemy {
                recordAction(for: actor, context: &context)
            }
            return actor.role == .enemy
        }
        let outcomes = BattleAbilityRules.possibleOutcomes(ability, action: action, in: context)
        let resolvedAbility = outcomes.resolve(using: &context.rng)
        let facts = ResolvedActionFacts(original: ability, resolved: resolvedAbility, action: action, origin: origin, in: context)
        let blockCost = resolvedAbility.blockCost
        let deductedBlock: Int
        if blockCost > 0 {
            let balance = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: actor))
            deductedBlock = min(balance, blockCost)
            DefensePoolEngine.set(balance - deductedBlock, on: actor, in: &context)
        } else {
            deductedBlock = 0
        }
        var committed = false
        defer {
            if !committed, deductedBlock > 0 {
                let remaining = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: actor))
                // Restore only the payment, preserving gains from interception reactions.
                DefensePoolEngine.set(SaturatedArithmetic.saturatingAdd(remaining, deductedBlock), on: actor, in: &context)
            }
        }
        if entry == .enemyTurn {
            let actionsBeforeInterception = context.roster.enemy.actionCount
            let interception = await CombatTriggerEngine.beforeEnemyAttack(facts, in: &context)

            guard !interception else {
                if context.roster.enemy.actionCount == actionsBeforeInterception {
                    recordAction(for: actor, context: &context)
                }
                return false
            }
        }
        committed = true
        let repeats = reserveCardRepeat(for: actor, origin: origin, enemyTurn: entry == .enemyTurn, in: &context)
        context.commandOutput?.beginAction(
            id: actionID, actorID: actor.id,
            abilityID: resolvedAbility.id, isAttack: resolvedAbility.dealsCombatDamage, afterEventID: context.nextEventID,
        )
        if blockCost > 0 {
            context.nextEvent(
                kind: .effect(.blockSpent), source: .init(actor),
                abilityID: ability.id, abilityName: ability.name, target: actor, amount: blockCost, keyword: .block, origin: .direct,
            )
        }
        _ = context.resolution.prepareAction(facts)
        let checkpoint = CombatCheckpoint.preparedAction(actor.id)
        if checkpoint.allowsContinuation(in: context) {
            UniqueCombatEngine.prepareResolvedAttack(facts, in: &context)
        }
        await executePreparedAction(facts, repeats: repeats, context: &context)
        return true
    }

    private static func executePreparedAction(
        _ facts: ResolvedActionFacts,
        repeats: Bool,
        context: inout BattleState,
    ) async {
        let actor = facts.action.actor
        var resolvedAbility = prepareTalentAction(ability: facts.ability, actor: actor, in: &context)

        await spendManaToEmpowerBurnOrFreezeIfNeeded(for: &resolvedAbility, actor: actor, context: &context)
        if CombatCheckpoint.preparedAction(actor.id).allowsContinuation(in: context) {
            if resolvedAbility.dealsCombatDamage {
                await consumeHemorrhageIfActive(for: actor, in: &context)
            }
        }

        await executePreparedOperations(facts, ability: resolvedAbility, context: &context)
        recordAction(for: actor, context: &context)
        context.commandOutput?.endAction()
        if repeats {
            await repeatPreparedCard(facts, ability: resolvedAbility, context: &context)
        }
    }

    package static func selectedEnemyAbility(for actor: Combatant, turnNumber: Int) -> Ability? {
        let tier = preferredTier(for: turnNumber)
        return actor.abilityLoadout.ability(for: tier)
            ?? actor.abilityLoadout.basic
            ?? actor.abilities.first
    }

    package static func preferredTier(for turnNumber: Int) -> AbilityTier {
        if turnNumber.isMultiple(of: AbilityTier.ultimate.cadenceTurns) {
            return .ultimate
        }
        if turnNumber.isMultiple(of: AbilityTier.skill.cadenceTurns) {
            return .skill
        }
        return .basic
    }

    private static func recordAction(
        for actor: Combatant,
        context: inout BattleState,
    ) {
        context.actionCount += 1
        context.roster.mutateRuntime(for: actor) { runtime in
            runtime.markActed()
        }
    }
}
