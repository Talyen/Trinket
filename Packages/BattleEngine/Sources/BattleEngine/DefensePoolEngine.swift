import Foundation
import TrinketContent
import TrinketCore

/// Shared helpers for the pooled Block / Armor model.
package enum DefensePoolEngine {
    /// Player-facing pool identity. Maps to `Effect.shield` / `Effect.mitigation`.
    package enum Pool: Sendable {
        case block
        case armor

        var effectKind: EffectKind {
            switch self {
            case .block: .shield
            case .armor: .mitigation
            }
        }

        var appliedEffectKind: ActionEvent.EffectKind {
            switch self {
            case .block: .shieldApplied
            case .armor: .mitigationApplied
            }
        }

        fileprivate var defaultKeyword: Keyword {
            switch self {
            case .block: .block
            case .armor: .armor
            }
        }

        fileprivate func matches(_ effect: Effect) -> Bool {
            switch (self, effect) {
            case (.block, .shield), (.armor, .mitigation): true
            default: false
            }
        }

        fileprivate func points(in effect: Effect) -> Int? {
            switch (self, effect) {
            case let (.block, .shield(_, buffer)): buffer
            case let (.armor, .mitigation(_, points)): points
            default: nil
            }
        }

        func decodeGain(_ effect: Effect) -> (keyword: Keyword, amount: Int)? {
            switch (self, effect) {
            case let (.block, .shield(keyword, amount)): (keyword, amount)
            case let (.armor, .mitigation(keyword, amount)): (keyword, amount)
            default: nil
            }
        }

        fileprivate func makeEffect(keyword: Keyword, amount: Int) -> Effect {
            switch self {
            case .block: .shield(keyword, amount)
            case .armor: .mitigation(keyword, amount)
            }
        }

        fileprivate func withAmount(_ effect: Effect, amount: Int) -> Effect? {
            switch (self, effect) {
            case let (.block, .shield(keyword, _)): .shield(keyword, amount)
            case let (.armor, .mitigation(keyword, _)): .mitigation(keyword, amount)
            default: nil
            }
        }
    }

    package static func points(in effects: [ActiveEffect], pool: Pool) -> Int {
        effects.reduce(0) { sum, active in
            sum + (pool.points(in: active.effect) ?? 0)
        }
    }

    package static func effectiveArmor(
        for combatant: Combatant,
        effects: [ActiveEffect],
        profile: CombatModifierProfile,
        in context: BattleEngineContext
    ) -> Int {
        var points = Self.points(in: effects, pool: .armor) + profile.passiveArmorFlat
        points += combatant.primaryStats.armorEffectivenessBonus
        if let runtime = context.roster.runtime(for: combatant),
           runtime.mitigationShredUntilTick > context.tickCount {
            points = Int(floor(Double(points) * runtime.mitigationShredMultiplier))
        }
        if profile.armorEffectivenessPenaltyPercent > 0 {
            points = Int(floor(Double(points) * max(0, 1 - profile.armorEffectivenessPenaltyPercent)))
        }
        return max(0, points)
    }

    package static func add(
        _ amount: Int,
        pool: Pool,
        to target: Combatant,
        keyword: Keyword? = nil,
        in context: inout BattleEngineContext
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
                remainingTicks: 0,
                sourceActorID: effects[index].sourceActorID
            )
            context.roster.setActiveEffects(effects, for: target)
            return
        }
        context.appendEffect(
            pool.makeEffect(keyword: keyword ?? pool.defaultKeyword, amount: amount),
            to: target,
            sourceID: target.id,
            remainingTicks: 0
        )
    }

    package static func set(
        _ amount: Int,
        pool: Pool,
        on target: Combatant,
        in context: inout BattleEngineContext
    ) {
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll { pool.matches($0.effect) }
        context.roster.setActiveEffects(effects, for: target)
        if amount > 0 {
            context.appendEffect(
                pool.makeEffect(keyword: pool.defaultKeyword, amount: amount),
                to: target,
                sourceID: target.id,
                remainingTicks: 0
            )
        }
    }

    /// Halves pooled Block at end of round (floor).
    package static func decayBlockAtEndOfRound(
        on target: Combatant,
        in context: inout BattleEngineContext
    ) {
        let current = points(in: context.roster.activeEffects(for: target), pool: .block)
        guard current > 0 else { return }
        set(current / 2, pool: .block, on: target, in: &context)
    }
}
