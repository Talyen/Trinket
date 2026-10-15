import TrinketContent
import TrinketCore

extension EffectHandlers {
    static func summarizeDeathsDoor(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard !stacks.isEmpty else { return nil }
        return EffectSummary(
            keyword: keyword,
            text: "Death's Door: Immune to fatal damage while active",
        )
    }

    static func advanceDeathsDoor(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) async {
        var updated = active
        updated.remainingTurns -= 1
        ActiveEffectMutation.finishTurn(
            active, replacement: updated.remainingTurns > 0 ? updated : nil, on: target, in: &context,
        )
        if updated.remainingTurns <= 0 {
            context.roster.mutateRuntime(for: target) {
                $0.deathsDoorExpiredAtTurn = context.turnCount
            }
            context.nextEvent(
                kind: .effect(.deathsDoorExpired),
                source: .init(target),
                abilityName: Keyword.deathsDoor.rawValue,
                target: target,
                amount: 0,
                keyword: .deathsDoor,
                origin: .direct,
            )
            await DeathsDoorEngine.afterDeathsDoorExpired(on: target, in: &context)
            return
        }
    }
}
