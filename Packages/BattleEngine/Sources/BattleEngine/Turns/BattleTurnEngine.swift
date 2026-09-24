import Foundation
import TrinketContent
import TrinketCore

package enum BattleTurnEngine {
    package static func consumeActionSkip(
        for actor: Combatant,
        context: inout BattleState,
    ) -> [ActionEvent] {
        var keyword: Keyword?
        var recovered = false

        context.roster.mutateRuntime(for: actor) { runtime in
            guard let index = runtime.activeEffects.firstIndex(where: \.isAwaitingActionSkip) else { return }
            var effect = runtime.activeEffects[index]
            keyword = effect.keyword
            let extraSkips = context.additionalControlSkipsByCombatantID[actor.id, default: 0]
            if extraSkips > 0 {
                context.additionalControlSkipsByCombatantID[actor.id] = extraSkips - 1
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

        if actor.role == .enemy, keyword == .stun, recovered {
            events.append(contentsOf: CombatCheckpoint.controlRecovery(actor.id, .stun).resolve([
                { CombatTriggerEngine.afterEnemyStunRecover(in: &$0) },
            ], in: &context))
        }

        recordAction(for: actor, context: &context)
        return events
    }

    package static func performAction(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        origin: DamageOperation.AttackOrigin = .ability,
        context: inout BattleState,
    ) -> [ActionEvent] {
        resolveAction(ability: ability, actor: actor, abilityTarget: abilityTarget, origin: origin, entry: .ordinary, context: &context)
            .events
    }

    static func performEnemyAction(
        ability: Ability, abilityTarget: Combatant, context: inout BattleState,
    ) -> (events: [ActionEvent], performed: Bool) {
        resolveAction(
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
    ) -> (events: [ActionEvent], performed: Bool) {
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
            let interception = CombatTriggerEngine.beforeEnemyAttack(facts, in: &context)
            events.append(contentsOf: interception.events)
            guard !interception.cancelled else {
                if context.roster.enemy.actionCount == actionsBeforeInterception {
                    recordAction(for: actor, context: &context)
                }
                return (events, false)
            }
        }
        committed = true
        context.cardPlayRecording?.beginAction(
            id: actionID, actorID: actor.id,
            abilityID: resolvedAbility.id, isAttack: resolvedAbility.dealsCombatDamage, afterEventID: context.nextEventID,
        )
        defer { context.cardPlayRecording?.endAction(state: context) }
        if blockCost > 0 {
            events.append(context.nextEvent(
                kind: .effect, effectKind: .blockSpent, actorName: actor.name,
                abilityName: ability.name, target: actor, amount: blockCost, keyword: .block, origin: .direct,
            ))
        }
        _ = context.resolution.prepareAction(facts)
        let checkpoint = CombatCheckpoint.preparedAction(actor.id)
        checkpoint.perform(in: &context) { UniqueCombatEngine.prepareResolvedAttack(facts, in: &$0) }
        events.append(contentsOf: executePreparedAction(facts, context: &context))
        return (events, true)
    }

    private static func executePreparedAction(_ facts: ResolvedActionFacts, context: inout BattleState) -> [ActionEvent] {
        let actor = facts.action.actor
        let abilityTarget = facts.action.selectedTarget
        var resolvedAbility = prepareTalentAction(ability: facts.ability, actor: actor, in: &context)
        var events: [ActionEvent] = []
        events.append(contentsOf: spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &resolvedAbility,
            actor: actor,
            context: &context,
        ))
        CombatCheckpoint.preparedAction(actor.id).perform(in: &context) { context in
            if resolvedAbility.dealsCombatDamage {
                events.append(contentsOf: consumeHemorrhageIfActive(for: actor, in: &context))
            }
        }

        var totalDealt = 0
        var logKeyword = resolvedAbility.logDamageKeyword
        var appliedEffectLogs: [String] = []
        var reservedKeywordOverride: Keyword?
        for operation in resolvedAbility.operations {
            switch operation {
            case let .damage(component):
                let outcome = applyDamageComponents(
                    [component], ability: resolvedAbility, actor: actor, abilityTarget: abilityTarget,
                    guaranteedCritical: facts.guaranteedCritical,
                    reservedKeywordOverride: &reservedKeywordOverride, context: &context,
                )
                events.append(contentsOf: outcome.events)
                totalDealt += outcome.totalDealt
                logKeyword = outcome.logDamageKeyword ?? logKeyword
            case let .effect(targeted):
                appliedEffectLogs.append(contentsOf: applyTargetedEffects(
                    [targeted], ability: resolvedAbility, actor: actor, abilityTarget: abilityTarget,
                    context: &context, events: &events,
                ))
            }
        }

        events.append(
            context.nextEvent(
                kind: .ability,
                effectKind: nil,
                actorID: actor.id,
                actorName: actor.name,
                abilityID: resolvedAbility.id,
                abilityName: resolvedAbility.name,
                abilityTier: resolvedAbility.tier,
                target: abilityTarget,
                amount: totalDealt,
                keyword: logKeyword,
                appliedEffectSummaries: appliedEffectLogs,
            ),
        )

        events.append(contentsOf: UniqueCombatEngine.repeatCardDamage(actor: actor, in: &context))
        recordAction(for: actor, context: &context)
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
