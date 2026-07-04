import Foundation
import TrinketContent
import TrinketCore

public enum CombatantLevelScaler {
    public static func scale(combatant: Combatant, level: Int) -> Combatant {
        let levelsAbove = StatGrowth.levelsAboveIdentity(level)
        let growth = StatGrowth.playerGrowth(
            archetype: combatant.growthArchetype,
            levelsAbove: levelsAbove
        )
        return scaledCombatant(combatant, growth: growth)
    }

    public static func scale(enemy: Enemy, level: Int) -> Combatant {
        let levelsAbove = StatGrowth.levelsAboveIdentity(level)
        let growth = StatGrowth.enemyGrowth(
            archetype: enemy.combatant.growthArchetype,
            isBoss: enemy.isBoss,
            levelsAbove: levelsAbove,
            identityStats: enemy.combatant.primaryStats
        )
        let scaled = scaledCombatant(enemy.combatant, growth: growth)
        return applyEnemyGearCompensation(
            to: scaled,
            level: level,
            isBoss: enemy.isBoss,
            isElite: enemy.isElite
        )
    }

    private static func scaledCombatant(_ combatant: Combatant, growth: StatGrowthDelta) -> Combatant {
        let scaled = StatGrowth.apply(
            maxHealth: combatant.maxHealth,
            maxMana: combatant.maxMana,
            primaryStats: combatant.primaryStats,
            growth: growth
        )
        return Combatant(
            id: combatant.id,
            name: combatant.name,
            role: combatant.role,
            maxHealth: scaled.maxHealth,
            maxMana: scaled.maxMana,
            actionIntervalTicks: combatant.actionIntervalTicks,
            abilityChoices: combatant.abilityChoices,
            primaryStats: scaled.primaryStats,
            growthArchetype: combatant.growthArchetype
        )
    }

    /// Compensates for player gear at higher levels without giving enemies equipment.
    private static func applyEnemyGearCompensation(
        to combatant: Combatant,
        level: Int,
        isBoss: Bool,
        isElite: Bool
    ) -> Combatant {
        let compensation = StatGrowth.enemyGearCompensation(
            level: level,
            identityStats: combatant.primaryStats,
            isBoss: isBoss,
            isElite: isElite
        )
        guard compensation != .none else { return combatant }

        let scaledHealth = max(
            1,
            Int((Double(combatant.maxHealth) * compensation.healthMultiplier).rounded())
        )
        let merged = StatGrowth.apply(
            maxHealth: scaledHealth,
            maxMana: combatant.maxMana,
            primaryStats: combatant.primaryStats,
            growth: compensation.statDelta
        )
        let scaledPrimaryStats = scalePrimaryStats(
            merged.primaryStats,
            multiplier: compensation.primaryStatMultiplier
        )

        return Combatant(
            id: combatant.id,
            name: combatant.name,
            role: combatant.role,
            maxHealth: merged.maxHealth,
            maxMana: merged.maxMana,
            actionIntervalTicks: combatant.actionIntervalTicks,
            abilityChoices: combatant.abilityChoices,
            primaryStats: scaledPrimaryStats,
            growthArchetype: combatant.growthArchetype
        )
    }

    private static func scalePrimaryStats(
        _ stats: PrimaryStats,
        multiplier: Double
    ) -> PrimaryStats {
        guard multiplier != 1.0 else { return stats }
        return PrimaryStats(
            strength: scaledStat(stats.strength, multiplier: multiplier),
            agility: scaledStat(stats.agility, multiplier: multiplier),
            toughness: scaledStat(stats.toughness, multiplier: multiplier),
            intellect: scaledStat(stats.intellect, multiplier: multiplier),
            wisdom: scaledStat(stats.wisdom, multiplier: multiplier)
        )
    }

    private static func scaledStat(_ value: Int, multiplier: Double) -> Int {
        max(0, Int((Double(value) * multiplier).rounded()))
    }
}
