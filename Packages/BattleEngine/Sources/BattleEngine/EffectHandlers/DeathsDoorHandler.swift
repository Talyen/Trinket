import Foundation
import TrinketContent
import TrinketCore

struct DeathsDoorHandler: BattleEffectHandler {
    let kind: EffectKind = .deathsDoor

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard !stacks.isEmpty else { return nil }
        return EffectSummary(
            keyword: keyword,
            text: "Death's Door: heal soon or the next fatal blow will end them."
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in _: inout BattleState
    ) -> EffectApplyOutcome {
        _ = effect; _ = ability; _ = source; _ = target
        return EffectApplyOutcome(events: [], didApply: false)
    }

    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState
    ) -> EffectTurnOutcome {
        var updated = active
        updated.remainingTurns -= 1
        if updated.remainingTurns <= 0 {
            context.roster.mutateRuntime(for: target) {
                $0.deathsDoorExpiredAtTurn = context.turnCount
            }
            let event = context.nextEvent(
                kind: .effect,
                effectKind: .deathsDoorExpired,
                actorName: target.name,
                abilityName: Keyword.deathsDoor.rawValue,
                target: target,
                amount: 0,
                keyword: .deathsDoor
            )
            return EffectTurnOutcome(events: [event], removeAfter: true)
        }
        return EffectTurnOutcome(updatedStack: updated)
    }
}
