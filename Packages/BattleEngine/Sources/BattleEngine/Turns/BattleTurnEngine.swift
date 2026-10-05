import Foundation
import TrinketContent
import TrinketCore

package enum BattleTurnEngine {
    package static func consumeActionSkip(
        for actor: Combatant,
        context: inout BattleState,
    ) async -> [ActionEvent] {
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
            return []
        }

        let event = context.nextEvent(
            kind: .effect,
            effectKind: .controlActionSkipped,
            actorName: keyword.statusAlias ?? keyword.rawValue,
            abilityName: keyword.statusAlias ?? keyword.rawValue,
            target: actor,
            amount: 0,
            keyword: keyword,
        )
        var events = [event]

        if keyword == .stun, recovered {
            applyStunRecoveryReduction(for: actor, context: &context)
        }
        if actor.role == .enemy, keyword == .stun, recovered {
            await events.append(contentsOf: CombatCheckpoint.controlRecovery(actor.id, .stun).resolve([
                { await CombatTriggerEngine.afterEnemyStunRecover(in: &$0) },
            ], in: &context))
        }

        recordAction(for: actor, context: &context)
        return events
    }

    private static func applyStunRecoveryReduction(for actor: Combatant, context: inout BattleState) {
        let opponents = BattleActionContext(actor: actor, in: context).opponents(in: context)
            .filter { context.health(of: $0) > 0 }
        let multiplier = opponents.reduce(1.0) {
            $0 * context.modifiers(for: $1.id).triggers.stunnedEnemyNextTurnDamageMultiplier
        }
        guard multiplier < 1, let source = opponents.first(where: {
            context.modifiers(for: $0.id).triggers.stunnedEnemyNextTurnDamageMultiplier < 1
        }) else { return }
        // Round expiry follows this skipped action; retain the reduction through the recovery turn.
        context.appendEffect(.damageReductionPercent(1 - multiplier, 2), to: actor, sourceID: source.id, remainingTurns: 2)
    }

    package static func performAction(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        origin: DamageOperation.AttackOrigin = .ability,
        context: inout BattleState,
    ) async -> [ActionEvent] {
        await resolveAction(
            ability: ability,
            actor: actor,
            abilityTarget: abilityTarget,
            origin: origin,
            entry: .ordinary,
            context: &context,
        )
        .events
    }

    static func performEnemyAction(
        ability: Ability, abilityTarget: Combatant, context: inout BattleState,
    ) async -> (events: [ActionEvent], performed: Bool) {
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
    ) async -> (events: [ActionEvent], performed: Bool) {
        let action = BattleActionContext(actor: actor, selectedTarget: abilityTarget)
        guard !context.isBattleOver, action.canContinue(in: context) else { return ([], false) }
        let previousFeedbackGroup = context.resolution.beginFeedbackGroup(eventID: context.nextEventID + 1)
        defer { context.resolution.feedbackGroupID = previousFeedbackGroup }
        let actionID = context.resolution.beginAction(action, origin: origin)
        defer { context.resolution.endAction() }
        var events: [ActionEvent] = []
        context.roster.mutateRuntime(for: actor) { $0.talents.beginAction() }
        guard BattleAbilityRules.canPayHealthCost(ability, actor: actor, in: context) else {
            if actor.role == .enemy {
                recordAction(for: actor, context: &context)
            }
            return ([], actor.role == .enemy)
        }
        let resolvedAbility = BattleAbilityRules.resolveOutcome(ability, actor: actor, in: &context)
        let facts = ResolvedActionFacts(original: ability, resolved: resolvedAbility, action: action, origin: origin, in: context)
        let blockCost = resolvedAbility.blockCost
        if blockCost > 0 {
            let balance = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: actor))
            DefensePoolEngine.set(balance - blockCost, on: actor, in: &context)
        }
        var committed = false
        defer {
            if !committed, blockCost > 0 {
                let remaining = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: actor))
                DefensePoolEngine.set(remaining + blockCost, on: actor, in: &context)
            }
        }
        if entry == .enemyTurn {
            let actionsBeforeInterception = context.roster.enemy.actionCount
            let interception = await CombatTriggerEngine.beforeEnemyAttack(facts, in: &context)
            events.append(contentsOf: interception.events)
            guard !interception.cancelled else {
                if context.roster.enemy.actionCount == actionsBeforeInterception {
                    recordAction(for: actor, context: &context)
                }
                return (events, false)
            }
        }
        committed = true
        let repeats = reserveCardRepeat(for: actor, origin: origin, enemyTurn: entry == .enemyTurn, in: &context)
        context.cardPlayRecording?.beginAction(
            id: actionID, actorID: actor.id,
            abilityID: resolvedAbility.id, isAttack: resolvedAbility.dealsCombatDamage, afterEventID: context.nextEventID,
        )
        if blockCost > 0 {
            events.append(context.nextEvent(
                kind: .effect, effectKind: .blockSpent, actorName: actor.name,
                abilityName: ability.name, target: actor, amount: blockCost, keyword: .block, origin: .direct,
            ))
        }
        _ = context.resolution.prepareAction(facts)
        let checkpoint = CombatCheckpoint.preparedAction(actor.id)
        await checkpoint.perform(in: &context) { UniqueCombatEngine.prepareResolvedAttack(facts, in: &$0) }
        await events.append(contentsOf: executePreparedAction(facts, repeats: repeats, context: &context))
        return (events, true)
    }

    private static func executePreparedAction(
        _ facts: ResolvedActionFacts,
        repeats: Bool,
        context: inout BattleState,
    ) async -> [ActionEvent] {
        let actor = facts.action.actor
        var resolvedAbility = prepareTalentAction(ability: facts.ability, actor: actor, in: &context)
        var events: [ActionEvent] = []
        await events.append(contentsOf: spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &resolvedAbility,
            actor: actor,
            context: &context,
        ))
        await CombatCheckpoint.preparedAction(actor.id).perform(in: &context) { context in
            if resolvedAbility.dealsCombatDamage {
                await events.append(contentsOf: consumeHemorrhageIfActive(for: actor, in: &context))
            }
        }

        await events.append(contentsOf: executePreparedOperations(facts, ability: resolvedAbility, context: &context))
        recordAction(for: actor, context: &context)
        context.cardPlayRecording?.endAction(state: context)
        if repeats {
            await events.append(contentsOf: repeatPreparedCard(facts, ability: resolvedAbility, context: &context))
        }
        return events
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
