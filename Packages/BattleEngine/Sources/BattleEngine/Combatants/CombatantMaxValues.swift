import TrinketContent
import TrinketCore

public enum CombatantMaxValues {
    public static func maxHealth(for combatant: Combatant, modifiers: CombatModifierProfile) -> Int {
        CombatRounding.scaled(
            SaturatedArithmetic.saturatingAdd(combatant.maxHealth, modifiers.maximumHealthBonus),
            multiplier: 1 + modifiers.maximumHealthPercentBonus,
        )
    }

    public static func maxMana(for combatant: Combatant, modifiers: CombatModifierProfile) -> Int {
        guard combatant.hasMana else { return 0 }
        let baseWithFlat = SaturatedArithmetic.saturatingAdd(combatant.maxMana, modifiers.maximumManaBonus)
        let multiplier = max(0, 1.0 + modifiers.maximumManaPercentBonus)
        return CombatRounding.rounded(Double(baseWithFlat) * multiplier)
    }

    public static func maxHealth(for combatant: Combatant, flatBonus: Int, talentBonus: Int = 0) -> Int {
        SaturatedArithmetic.saturatingAdd(
            SaturatedArithmetic.saturatingAdd(combatant.maxHealth, flatBonus), talentBonus,
        )
    }

    public static func maxMana(for combatant: Combatant, flatBonus: Int, effectBonus: Int = 0) -> Int {
        guard combatant.hasMana else { return 0 }
        return SaturatedArithmetic.saturatingAdd(
            SaturatedArithmetic.saturatingAdd(combatant.maxMana, flatBonus), effectBonus,
        )
    }
}
