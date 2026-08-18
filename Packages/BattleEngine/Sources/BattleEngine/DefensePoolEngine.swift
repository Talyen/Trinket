import Foundation
import TrinketContent
import TrinketCore

/// Shared helpers for the pooled Block model and Toughness-based inherent DR.
package enum DefensePoolEngine {
    package static func blockPoints(in effects: [ActiveEffect]) -> Int {
        effects.reduce(0) { sum, active in
            if case let .shield(_, buffer) = active.effect {
                return sum + buffer
            }
            return sum
        }
    }

    /// Inherent Toughness-based damage reduction percent.
    /// No pool points — Toughness DR is never consumed or decayed.
    package static func effectiveToughnessMitigationPercent(
        for combatant: Combatant,
        effects _: [ActiveEffect],
        profile _: CombatModifierProfile,
        in _: BattleState
    ) -> Double {
        max(0.0, min(1.0, combatant.primaryStats.toughnessMitigationPercent))
    }

    /// Adds fight-paced Block points. Returns the paced amount actually applied (0 when skipped).
    @discardableResult
    package static func add(
        _ amount: Int,
        to target: Combatant,
        keyword: Keyword = .block,
        sourceActorID: String? = nil,
        in context: inout BattleState
    ) -> Int {
        let pacedAmount = sourceActorID.map { context.paced(amount, sourceActorID: $0) } ?? amount
        guard pacedAmount > 0 else { return 0 }
        var effects = context.roster.activeEffects(for: target)
        if let index = effects.firstIndex(where: {
            if case .shield = $0.effect {
                return true
            }
            return false
        }), case let .shield(existingKeyword, existingBuffer) = effects[index].effect {
            effects[index] = ActiveEffect(
                id: effects[index].id,
                effect: .shield(existingKeyword, existingBuffer + pacedAmount),
                remainingTurns: 0,
                sourceActorID: effects[index].sourceActorID
            )
            context.roster.setActiveEffects(effects, for: target)
            return pacedAmount
        }
        context.appendEffect(
            .shield(keyword, pacedAmount),
            to: target,
            sourceID: sourceActorID ?? target.id,
            remainingTurns: 0
        )
        return pacedAmount
    }

    package static func set(
        _ amount: Int,
        on target: Combatant,
        in context: inout BattleState
    ) {
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll {
            if case .shield = $0.effect {
                return true
            }
            return false
        }
        context.roster.setActiveEffects(effects, for: target)
        if amount > 0 {
            context.appendEffect(
                .shield(.block, amount),
                to: target,
                sourceID: target.id,
                remainingTurns: 0
            )
        }
    }

    /// Halves pooled Block at end of round (floor). Combatants with
    /// `blockRetainsThreeQuarters` retain 75% instead, capped at 30 (Unbreakable / Enduring Shell).
    package static func decayBlockAtEndOfRound(
        on target: Combatant,
        in context: inout BattleState
    ) {
        let current = blockPoints(in: context.roster.activeEffects(for: target))
        guard current > 0 else { return }
        if context.modifiers(for: target.id).triggers.blockRetainsThreeQuarters {
            let retained = min(30, (current * 3) / 4)
            set(retained, on: target, in: &context)
            return
        }
        set(current / 2, on: target, in: &context)
    }

    /// Halves pooled Block (floor). Used by `Effect.halveShield`.
    package static func halveBlock(
        on target: Combatant,
        in context: inout BattleState
    ) -> Bool {
        let current = blockPoints(in: context.roster.activeEffects(for: target))
        guard current > 0 else { return false }
        set(current / 2, on: target, in: &context)
        return true
    }
}
