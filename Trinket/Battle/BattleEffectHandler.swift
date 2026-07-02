import Foundation

/// Result of dispatching a single `Effect` through a `BattleEffectHandler`.
/// The caller (currently `BattleState.performAction`) merges these into the
/// surrounding action's event stream and log-line buffer.
struct EffectApplyOutcome {
    /// Events to append to the action's event stream. May be empty.
    var events: [ActionEvent] = []

    /// When `true`, the caller should append `effect.summary` to the
    /// log-line buffer. The `preventionBuildup` handler returns `false`
    /// because it does no work during apply (the buildup is created
    /// inside `applyDamage` when stun/freeze damage lands).
    var didApply: Bool = true
}

/// Result of dispatching a single `ActiveEffect` through a
/// `BattleEffectHandler.tick`. The caller (`BattleState.tickEffects`)
/// merges these into the per-tick event stream and the per-effect
/// updated/removed list.
struct EffectTickOutcome {
    /// Events to append to the per-tick event stream. May be empty.
    var events: [ActionEvent] = []

    /// The handler's updated view of the active effect. When `nil`, the
    /// caller leaves the effect unchanged.
    var updatedStack: ActiveEffect?

    /// When `true`, the caller should drop this active effect from the
    /// list after the per-handler tick pass. The bleed/burn/poison
    /// handlers set this once their potency or remaining ticks reach 0.
    var removeAfter: Bool = false
}

/// One handler per `EffectKind`. Handlers are stateless value types
/// registered in a lookup table (`EffectHandlers.all`). New effect types
/// add a case to `EffectKind`, a case to `Effect`, and one handler struct
/// (plus a table entry) — no edits to `BattleState.performAction` required.
protocol BattleEffectHandler: Sendable {
    var kind: EffectKind { get }
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome
    func tick(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectTickOutcome
    /// Builds the player-facing summary line for a stack of active effects
    /// of this kind, all sharing the same `keyword`. Returning `nil` means
    /// "this kind has no summary for this stack"; the builder will try the
    /// next kind in priority order.
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary?
}

extension BattleEffectHandler {
    /// Default: decrement `remainingTicks` for tickable buffs and debuffs that
    /// do not override `tick`. Burn, Poison, Bleed, Cleanse, Prevention, and
    /// PreventionBuildup provide their own tick behavior.
    func tick(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectTickOutcome {
        _ = target; _ = context
        switch active.effect {
        case .burn, .poison, .bleed, .cleanse, .prevention, .preventionBuildup:
            return EffectTickOutcome()
        default:
            guard active.effect.isTickable else { return EffectTickOutcome() }
            var updated = active
            updated.remainingTicks -= 1
            return EffectTickOutcome(
                updatedStack: updated,
                removeAfter: updated.remainingTicks <= 0
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
