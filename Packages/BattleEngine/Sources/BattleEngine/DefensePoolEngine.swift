import Foundation
import TrinketContent
import TrinketCore

/// Shared helpers for the pooled Block model and Toughness-based inherent DR.
package enum DefensePoolEngine {
    /// Player-facing pool identity. Maps to `Effect.shield`.
    package enum Pool: Sendable {
        case block

        var effectKind: EffectKind {
            switch self {
            case .block: .shield
            }
        }

        var appliedEffectKind: ActionEvent.EffectKind {
            switch self {
            case .block: .shieldApplied
            }
        }

        fileprivate var defaultKeyword: Keyword {
            switch self {
            case .block: .block
            }
        }

        fileprivate func matches(_ effect: Effect) -> Bool {
            switch (self, effect) {
            case (.block, .shield): true
            default: false
            }
        }

        fileprivate func points(in effect: Effect) -> Int? {
            switch (self, effect) {
            case let (.block, .shield(_, buffer)): buffer
            default: nil
            }
        }

        func decodeGain(_ effect: Effect) -> (keyword: Keyword, amount: Int)? {
            switch (self, effect) {
            case let (.block, .shield(keyword, amount)): (keyword, amount)
            default: nil
            }
        }

        fileprivate func makeEffect(keyword: Keyword, amount: Int) -> Effect {
            switch self {
            case .block: .shield(keyword, amount)
            }
        }

        fileprivate func withAmount(_ effect: Effect, amount: Int) -> Effect? {
            switch (self, effect) {
            case let (.block, .shield(keyword, _)): .shield(keyword, amount)
            default: nil
            }
        }
    }

    package static func points(in effects: [ActiveEffect], pool: Pool) -> Int {
        effects.reduce(0) { sum, active in
            sum + (pool.points(in: active.effect) ?? 0)
        }
    }

    /// Inherent Toughness-based damage reduction percent: `toughnessMitigationPercent`,
    /// shredded and reduced by effectiveness penalties.
    /// No pool points — Toughness DR is never consumed or decayed.
    package static func effectiveToughnessMitigationPercent(
        for combatant: Combatant,
        effects _: [ActiveEffect],
        profile: CombatModifierProfile,
        in context: BattleState
    ) -> Double {
        var percent = combatant.primaryStats.toughnessMitigationPercent
        if let runtime = context.roster.runtime(for: combatant),
           runtime.mitigationShredUntilTurn > context.turnCount {
            percent *= runtime.mitigationShredMultiplier
        }
        if profile.triggers.mitigationEffectivenessPenaltyPercent > 0 {
            percent *= max(0, 1 - profile.triggers.mitigationEffectivenessPenaltyPercent)
        }
        return max(0.0, min(1.0, percent))
    }

    package static func add(
        _ amount: Int,
        pool: Pool,
        to target: Combatant,
        keyword: Keyword? = nil,
        in context: inout BattleState
    ) {
        guard amount > 0 else { return }
        var effects = context.roster.activeEffects(for: target)
        if let index = effects.firstIndex(where: { pool.matches($0.effect) }),
           let updated = pool.withAmount(
               effects[index].effect,
               amount: (pool.points(in: effects[index].effect) ?? 0) + amount
           ) {
            effects[index] = ActiveEffect(
                id: effects[index].id,
                effect: updated,
                remainingTurns: 0,
                sourceActorID: effects[index].sourceActorID
            )
            context.roster.setActiveEffects(effects, for: target)
            return
        }
        context.appendEffect(
            pool.makeEffect(keyword: keyword ?? pool.defaultKeyword, amount: amount),
            to: target,
            sourceID: target.id,
            remainingTurns: 0
        )
    }

    package static func set(
        _ amount: Int,
        pool: Pool,
        on target: Combatant,
        in context: inout BattleState
    ) {
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll { pool.matches($0.effect) }
        context.roster.setActiveEffects(effects, for: target)
        if amount > 0 {
            context.appendEffect(
                pool.makeEffect(keyword: pool.defaultKeyword, amount: amount),
                to: target,
                sourceID: target.id,
                remainingTurns: 0
            )
        }
    }

    /// Halves pooled Block at end of round (floor).
    package static func decayBlockAtEndOfRound(
        on target: Combatant,
        in context: inout BattleState
    ) {
        let current = points(in: context.roster.activeEffects(for: target), pool: .block)
        guard current > 0 else { return }
        set(current / 2, pool: .block, on: target, in: &context)
    }

    /// Halves pooled Block (floor). Used by `Effect.halveShield`.
    package static func halveBlock(
        on target: Combatant,
        in context: inout BattleState
    ) -> Bool {
        let current = points(in: context.roster.activeEffects(for: target), pool: .block)
        guard current > 0 else { return false }
        set(current / 2, pool: .block, on: target, in: &context)
        return true
    }
}
