import Foundation
import TrinketContent
import TrinketCore

package struct EffectApplyOutcome {
    package var didApply: Bool = true
    /// Direct grants exclude any gains produced by nested reactions.
    package var grantedGold: Int = 0
    package var restoredMana: Int = 0
    package var criticalAttackActorIDs: Set<String> = []
}

package protocol BattleEffectHandler: Sendable {
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) async -> EffectApplyOutcome
    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) async
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary?
}

package extension BattleEffectHandler {
    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
        // swiftlint:disable:next async_without_await - Match the async protocol witness so synchronous calls cannot bypass specialized turn handlers.
    ) async {
        guard active.effect.advancesEachTurn else { return }
        var updated = active
        updated.remainingTurns -= 1
        ActiveEffectMutation.finishTurn(
            active, replacement: updated.remainingTurns > 0 ? updated : nil, on: target, in: &context,
        )
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        _ = stacks; _ = keyword
        return nil
    }
}
