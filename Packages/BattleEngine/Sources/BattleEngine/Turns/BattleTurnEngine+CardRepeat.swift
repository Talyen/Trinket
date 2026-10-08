import TrinketContent
import TrinketCore

extension BattleTurnEngine {
    static func reserveCardRepeat(
        for actor: Combatant,
        origin: DamageOperation.AttackOrigin,
        enemyTurn: Bool,
        in context: inout BattleState,
    ) -> Bool {
        let manualCard = (origin == .card || origin == .ordinaryCard)
            && context.resolution.damageProvenance(for: actor.id)?.cardID != nil
        guard manualCard || enemyTurn, !context.resolution.isAutomaticPlay, !context.isEchoingSkill,
              context.roster.activeEffects(for: actor).contains(where: { $0.effect == .playNextCardTwice })
        else { return false }
        // Claim before effects can draw, echo, or ready another Shadowstep.
        ActiveEffectMutation.removeMatching(from: actor, in: &context) { $0.kind == .playNextCardTwice }
        return true
    }

    static func repeatPreparedCard(
        _ facts: ResolvedActionFacts,
        ability: Ability,
        context: inout BattleState,
    ) async -> [ActionEvent] {
        let actor = facts.action.actor
        guard !context.isBattleOver, facts.action.canContinue(in: context),
              BattleAbilityRules.canPayHealthCost(ability, actor: actor, in: context)
        else { return [] }
        let origin: DamageOperation.AttackOrigin = actor.role == .enemy ? .repeatedAttack : .cardRepeat
        let actionID = context.resolution.beginAction(facts.action, origin: origin)
        defer { context.resolution.endAction() }
        let repeated = ResolvedActionFacts(
            original: facts.originalAbility, resolved: ability, action: facts.action, origin: origin, in: context,
        )
        _ = context.resolution.prepareAction(repeated)
        context.resolution.prepareActionTalents(TalentActionFacts(actorID: actor.id))
        context.cardPlayRecording?.beginAction(
            id: actionID, actorID: actor.id, abilityID: ability.id,
            isAttack: ability.dealsCombatDamage, afterEventID: context.nextEventID,
        )
        defer { context.cardPlayRecording?.endAction(state: context) }
        // Replay prepared effects without another cost, empowerment, or card-completion cadence.
        return await executePreparedOperations(repeated, ability: ability, context: &context)
    }

    static func executePreparedOperations(
        _ facts: ResolvedActionFacts,
        ability resolvedAbility: Ability,
        context: inout BattleState,
    ) async -> [ActionEvent] {
        let actor = facts.action.actor
        let abilityTarget = facts.action.selectedTarget
        var events: [ActionEvent] = []
        var totalDealt = 0
        var logKeyword = resolvedAbility.damageKeyword
        var appliedEffectLogs: [String] = []
        var reservedKeywordOverride: Keyword?
        for operation in resolvedAbility.operations {
            switch operation {
            case let .damage(component):
                let outcome = await applyDamageComponent(
                    component, ability: resolvedAbility, actor: actor, abilityTarget: abilityTarget,
                    guaranteedCritical: facts.guaranteedCritical,
                    reservedKeywordOverride: &reservedKeywordOverride, context: &context,
                )
                events.append(contentsOf: outcome.events)
                totalDealt = SaturatedArithmetic.saturatingAdd(totalDealt, outcome.healthLost)
                logKeyword = outcome.logDamageKeyword ?? logKeyword
            case let .effect(targeted):
                await appliedEffectLogs.append(contentsOf: applyTargetedEffects(
                    [targeted], ability: resolvedAbility, actor: actor, abilityTarget: abilityTarget,
                    context: &context, events: &events,
                ))
            }
        }

        events.append(
            context.nextEvent(
                kind: .ability,
                actionID: context.resolution.actionID,
                effectKind: nil,
                source: .init(actor),
                abilityID: resolvedAbility.id,
                abilityName: resolvedAbility.name,
                abilityTier: resolvedAbility.tier,
                target: abilityTarget,
                amount: totalDealt,
                keyword: logKeyword,
                appliedEffectSummaries: appliedEffectLogs,
            ),
        )

        await events.append(contentsOf: UniqueCombatEngine.repeatCardDamage(actor: actor, in: &context))
        return events
    }
}
