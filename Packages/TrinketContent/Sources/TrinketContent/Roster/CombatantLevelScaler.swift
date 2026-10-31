import Foundation
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
        return combatant.withScaledStats(health: scaledHealth, mana: scaledMana)
    }

    public static func scale(enemy: Enemy, level: Int, profile: EnemyPowerCurve.Profile = .standard) -> Combatant {
        let base = enemy.combatant
        let healthMultiplier = EnemyPowerCurve.health(level: level, isBoss: enemy.isBoss, profile: profile)
        let scaledHealth = max(1, CombatRounding.scaled(base.maxHealth, multiplier: healthMultiplier))
        return base.withScaledStats(health: scaledHealth, mana: base.maxMana)
    }
}

private extension Combatant {
    func withScaledStats(health: Int, mana: Int) -> Self {
        Self(
            id: id,
            name: name,
            role: role,
            maxHealth: health,
            maxMana: mana,
            actionIntervalTurns: actionIntervalTurns,
            abilityChoices: abilityChoices,
        )
    }
}
