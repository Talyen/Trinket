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
            levelsAbove: levelsAbove
        )
        let scaled = scaledCombatant(enemy.combatant, growth: growth)
        let power = EnemyPowerCurve.multipliers(level: level, isBoss: enemy.isBoss)
        let powered = StatGrowth.applyPowerMultiplier(
            maxHealth: scaled.maxHealth,
            maxMana: scaled.maxMana,
            primaryStats: scaled.primaryStats,
            healthMultiplier: power.health,
            statsMultiplier: power.stats
        )
        return Combatant(
            id: scaled.id,
            name: scaled.name,
            role: scaled.role,
            maxHealth: powered.maxHealth,
            maxMana: powered.maxMana,
            actionIntervalTurns: scaled.actionIntervalTurns,
            abilityChoices: scaled.abilityChoices,
            primaryStats: powered.primaryStats,
            growthArchetype: scaled.growthArchetype
        )
    }

    public static func powerRating(for enemy: Enemy, level: Int) -> CombatPowerSnapshot {
        let scaled = scale(enemy: enemy, level: level)
        return CombatPowerRating.evaluate(
            maxHealth: scaled.maxHealth,
            primaryStats: scaled.primaryStats,
            level: level,
            powerMultiplier: EnemyPowerCurve.power(level: level, isBoss: enemy.isBoss)
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
            actionIntervalTurns: combatant.actionIntervalTurns,
            abilityChoices: combatant.abilityChoices,
            primaryStats: scaled.primaryStats,
            growthArchetype: combatant.growthArchetype
        )
    }
}
