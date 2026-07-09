import Foundation
import TrinketContent
import TrinketCore

public struct DeathsDoorHandler: BattleEffectHandler {
    public let kind: EffectKind = .deathsDoor

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard !stacks.isEmpty else { return nil }
        return EffectSummary(
            keyword: keyword,
            text: "Death's Door: heal soon or the next fatal blow will end them."
        )
    }

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in _: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        _ = effect; _ = ability; _ = source; _ = target
        return EffectApplyOutcome(events: [], didApply: false)
    }

    public func tick(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleEngineContext
    ) -> EffectTickOutcome {
        var updated = active
        updated.remainingTicks -= 1
        if updated.remainingTicks <= 0 {
            context.roster.mutateRuntime(for: target) {
                $0.deathsDoorExpiredAtTick = context.tickCount
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
            return EffectTickOutcome(events: [event], removeAfter: true)
        }
        return EffectTickOutcome(updatedStack: updated)
    }
}
