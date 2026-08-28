import Foundation
import TrinketContent
import TrinketCore

public struct EffectApplyOutcome {
    public var events: [ActionEvent] = []

    public var didApply: Bool = true
}

public struct EffectTurnOutcome {
    public var events: [ActionEvent] = []

    public var updatedStack: ActiveEffect?

    public var removeAfter: Bool = false
}

public protocol BattleEffectHandler: Sendable {
    var kind: EffectKind { get }
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> EffectApplyOutcome
    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState
    ) -> EffectTurnOutcome
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary?
}

public extension BattleEffectHandler {
    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState
    ) -> EffectTurnOutcome {
        _ = target; _ = context
        guard active.effect.advancesEachTurn else { return EffectTurnOutcome() }
        var updated = active
        updated.remainingTurns -= 1
        return EffectTurnOutcome(
            updatedStack: updated,
            removeAfter: updated.remainingTurns <= 0
        )
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        _ = stacks; _ = keyword
        return nil
    }
}
