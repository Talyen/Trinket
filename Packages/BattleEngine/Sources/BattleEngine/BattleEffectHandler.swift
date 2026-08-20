import Foundation
import TrinketContent
import TrinketCore

/// Result of dispatching a single `Effect` through a `BattleEffectHandler`.
/// The caller (`BattleTurnEngine.performAction`) merges these into the
/// surrounding action's event stream and log-line buffer.
public struct EffectApplyOutcome {
    /// Events to append to the action's event stream. May be empty.
    public var events: [ActionEvent] = []

    /// When `true`, the caller should append `effect.summary` to the
    /// log-line buffer.
    public var didApply: Bool = true
}

/// Result of dispatching a single `ActiveEffect` through a
/// `BattleEffectHandler.advanceTurn`. The caller (`EffectTurnEngine.advanceEffects`)
/// merges these into the per-turn event stream and the per-effect
/// updated/removed list.
public struct EffectTurnOutcome {
    /// Events to append to the per-turn event stream. May be empty.
    public var events: [ActionEvent] = []

    /// The handler's updated view of the active effect. When `nil`, the
    /// caller leaves the effect unchanged.
    public var updatedStack: ActiveEffect?

    /// When `true`, the caller should drop this active effect from the
    /// list after the per-handler turn pass.
    public var removeAfter: Bool = false
}

/// One handler per `EffectKind`. Handlers are stateless value types
/// registered in a lookup table (`EffectHandlers.all`). New effect types
/// add a case to `EffectKind`, a case to `Effect`, and one handler struct
/// (plus a table entry) — no edits to `BattleTurnEngine.performAction` required.
public protocol BattleEffectHandler: Sendable {
    var kind: EffectKind { get }
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome
    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState
    ) -> EffectTurnOutcome
    /// Builds the player-facing summary line for a stack of active effects
    /// of this kind, all sharing the same `keyword`. Returning `nil` means
    /// "this kind has no summary for this stack"; the builder will try the
    /// next kind in priority order.
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary?
}

public extension BattleEffectHandler {
    /// Default: decrement `remainingTurns` for timed buffs and debuffs that
    /// do not override `advanceTurn`. Burn, Poison, Bleed, and ControlMeter
    /// provide their own turn behavior.
    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState
    ) -> EffectTurnOutcome {
        _ = target; _ = context
        switch active.effect {
        case .burn, .poison, .bleed, .controlMeter, .deathsDoor:
            return EffectTurnOutcome()
        default:
            guard active.effect.advancesEachTurn else { return EffectTurnOutcome() }
            var updated = active
            updated.remainingTurns -= 1
            return EffectTurnOutcome(
                updatedStack: updated,
                removeAfter: updated.remainingTurns <= 0
            )
        }
    }

    /// Default: this kind has no player-facing summary. Instant effects
    /// and any effect kind that lives only in event streams opt out of
    /// summaries by relying on this default.
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        _ = stacks; _ = keyword
        return nil
    }
}
