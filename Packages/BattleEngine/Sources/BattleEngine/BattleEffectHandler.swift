import Foundation
import TrinketContent
import TrinketCore

public struct EffectApplyOutcome {
    public var events: [ActionEvent] = []

    public var didApply: Bool = true
}

public protocol BattleEffectHandler: Sendable {
    var kind: EffectKind { get }
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome
    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent]
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary?
}

public extension BattleEffectHandler {
    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard active.effect.advancesEachTurn else { return [] }
        var updated = active
        updated.remainingTurns -= 1
        ActiveEffectMutation.finishTurn(
            active, replacement: updated.remainingTurns > 0 ? updated : nil, on: target, in: &context,
        )
        return []
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        _ = stacks; _ = keyword
        return nil
    }
}
