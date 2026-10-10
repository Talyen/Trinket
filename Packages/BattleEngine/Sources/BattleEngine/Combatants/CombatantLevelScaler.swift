import Foundation
import TrinketContent
import TrinketCore

public enum CombatantLevelScaler {
    public static func scale(combatant: Combatant, level: Int) -> Combatant {
        let levelsAbove = max(1, level) - 1
        let healthBonus = SaturatedArithmetic.saturatingMul(levelsAbove, 2)
        let scaledHealth = SaturatedArithmetic.saturatingAdd(combatant.maxHealth, healthBonus)
        let scaledMana = if combatant.hasMana {
            SaturatedArithmetic.saturatingAdd(combatant.maxMana, levelsAbove / 2)
        } else {
            combatant.maxMana
        }
        return Combatant(
            id: combatant.id,
            name: combatant.name,
            role: combatant.role,
            maxHealth: scaledHealth,
            maxMana: scaledMana,
            actionIntervalTurns: combatant.actionIntervalTurns,
            abilityChoices: combatant.abilityChoices,
        )
    }

    public static func scale(enemy: Enemy, level: Int, profile: EnemyPowerCurve.Profile = .standard) -> Combatant {
        let base = enemy.combatant
        let healthMultiplier = EnemyPowerCurve.health(level: level, isBoss: enemy.isBoss, profile: profile)
        let scaledHealth = max(1, CombatRounding.scaled(base.maxHealth, multiplier: healthMultiplier))
        return Combatant(
            id: base.id,
            name: base.name,
            role: base.role,
            maxHealth: scaledHealth,
            maxMana: base.maxMana,
            actionIntervalTurns: base.actionIntervalTurns,
            abilityChoices: base.abilityChoices,
        )
    }

    public static func powerRating(
        for enemy: Enemy,
        level: Int,
        profile: EnemyPowerCurve.Profile = .standard,
    ) -> (level: Int, maxHealth: Int, rawDamagePercent: Double) {
        let scaled = scale(enemy: enemy, level: level, profile: profile)
        let rawDamage = EnemyPowerCurve.rawDamagePercent(level: level, isBoss: enemy.isBoss, profile: profile)
        return (
            level: level,
            maxHealth: scaled.maxHealth,
            rawDamagePercent: rawDamage,
        )
    }
}
