import Foundation
import TrinketContent
import TrinketCore

/// Shared helpers for the pooled Block / Armor model.
package enum DefensePoolEngine {
    package static func blockPoints(in effects: [ActiveEffect]) -> Int {
        effects.reduce(0) { sum, active in
            if case let .shield(_, buffer) = active.effect { return sum + buffer }
            return sum
        }
    }

    package static func armorPoints(in effects: [ActiveEffect]) -> Int {
        effects.reduce(0) { sum, active in
            if case let .mitigation(_, points) = active.effect { return sum + points }
            return sum
        }
    }

    package static func effectiveArmor(
        for combatant: Combatant,
        effects: [ActiveEffect],
        profile: CombatModifierProfile,
        in context: BattleEngineContext
    ) -> Int {
        var points = armorPoints(in: effects) + profile.passiveArmorFlat
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

    package static func addBlock(
        _ amount: Int,
        to target: Combatant,
        keyword: Keyword = .block,
        in context: inout BattleEngineContext
    ) {
        guard amount > 0 else { return }
        var effects = context.roster.activeEffects(for: target)
        if let index = effects.firstIndex(where: { if case .shield = $0.effect { return true }; return false }),
           case let .shield(existingKeyword, buffer) = effects[index].effect {
            effects[index] = ActiveEffect(
                id: effects[index].id,
                effect: .shield(existingKeyword, buffer + amount),
                remainingTicks: 0,
                sourceActorID: effects[index].sourceActorID
            )
            context.roster.setActiveEffects(effects, for: target)
            return
        }
        context.appendEffect(.shield(keyword, amount), to: target, sourceID: target.id, remainingTicks: 0)
    }

    package static func addArmor(
        _ amount: Int,
        to target: Combatant,
        keyword: Keyword = .armor,
        in context: inout BattleEngineContext
    ) {
        guard amount > 0 else { return }
        var effects = context.roster.activeEffects(for: target)
        if let index = effects.firstIndex(where: { if case .mitigation = $0.effect { return true }; return false }),
           case let .mitigation(existingKeyword, points) = effects[index].effect {
            effects[index] = ActiveEffect(
                id: effects[index].id,
                effect: .mitigation(existingKeyword, points + amount),
                remainingTicks: 0,
                sourceActorID: effects[index].sourceActorID
            )
            context.roster.setActiveEffects(effects, for: target)
            return
        }
        context.appendEffect(.mitigation(keyword, amount), to: target, sourceID: target.id, remainingTicks: 0)
    }

    package static func setArmor(
        _ amount: Int,
        on target: Combatant,
        in context: inout BattleEngineContext
    ) {
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll { if case .mitigation = $0.effect { return true }; return false }
        context.roster.setActiveEffects(effects, for: target)
        if amount > 0 {
            context.appendEffect(.mitigation(.armor, amount), to: target, sourceID: target.id, remainingTicks: 0)
        }
    }

    package static func setBlock(
        _ amount: Int,
        on target: Combatant,
        in context: inout BattleEngineContext
    ) {
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll { if case .shield = $0.effect { return true }; return false }
        context.roster.setActiveEffects(effects, for: target)
        if amount > 0 {
            context.appendEffect(.shield(.block, amount), to: target, sourceID: target.id, remainingTicks: 0)
        }
    }

    /// Halves pooled Block at end of round (floor).
    package static func decayBlockAtEndOfRound(
        on target: Combatant,
        in context: inout BattleEngineContext
    ) {
        let current = blockPoints(in: context.roster.activeEffects(for: target))
        guard current > 0 else { return }
        setBlock(current / 2, on: target, in: &context)
    }
}
