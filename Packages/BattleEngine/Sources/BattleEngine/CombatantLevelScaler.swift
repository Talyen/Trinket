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
        let compensated = StatGrowth.applyEnemyGearCompensation(
            maxHealth: scaled.maxHealth,
            maxMana: scaled.maxMana,
            primaryStats: scaled.primaryStats,
            level: level,
            isBoss: enemy.isBoss,
            isElite: enemy.isElite
        )
        return Combatant(
            id: scaled.id,
            name: scaled.name,
            role: scaled.role,
            maxHealth: compensated.maxHealth,
            maxMana: compensated.maxMana,
            actionIntervalTicks: scaled.actionIntervalTicks,
            abilityChoices: scaled.abilityChoices,
            primaryStats: compensated.primaryStats,
            growthArchetype: scaled.growthArchetype
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
}
