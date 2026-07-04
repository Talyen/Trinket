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
        return applyEnemyPowerBracket(to: scaled, level: level)
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

    /// Compensates for player gear at mid/late progression without giving enemies equipment.
    private static func applyEnemyPowerBracket(to combatant: Combatant, level: Int) -> Combatant {
        guard level >= SimulationPowerTier.middle.level else {
            return combatant
        }

        let bracket: StatGrowthDelta
        let healthMultiplier: Double
        if level >= SimulationPowerTier.lateGame.level {
            healthMultiplier = 1.25
            bracket = StatGrowth.enemyLateGameBracketBonus(identityStats: combatant.primaryStats)
        } else {
            healthMultiplier = 1.12
            bracket = StatGrowthDelta(toughness: 1)
        }

        let scaledHealth = max(
            1,
            Int((Double(combatant.maxHealth) * healthMultiplier).rounded()) + bracket.maxHealth
        )
        let merged = StatGrowth.apply(
            maxHealth: scaledHealth,
            maxMana: combatant.maxMana,
            primaryStats: combatant.primaryStats,
            growth: StatGrowthDelta(
                strength: bracket.strength,
                agility: bracket.agility,
                toughness: bracket.toughness,
                intellect: bracket.intellect,
                wisdom: bracket.wisdom,
                maxMana: bracket.maxMana
            )
        )

        return Combatant(
            id: combatant.id,
            name: combatant.name,
            role: combatant.role,
            maxHealth: merged.maxHealth,
            maxMana: merged.maxMana,
            actionIntervalTicks: combatant.actionIntervalTicks,
            abilityChoices: combatant.abilityChoices,
            primaryStats: merged.primaryStats,
            growthArchetype: combatant.growthArchetype
        )
    }
}
