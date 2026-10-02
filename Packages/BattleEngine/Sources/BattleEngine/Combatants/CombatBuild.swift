import TrinketContent

public struct CombatBuild: Equatable, Hashable, Sendable {
    public let combatant: Combatant
    public let modifiers: CombatModifierProfile

    public init(combatant: Combatant, modifiers: CombatModifierProfile) {
        self.combatant = combatant
        self.modifiers = modifiers
    }

    public var effectiveMaxHealth: Int {
        CombatantMaxValues.maxHealth(for: combatant, modifiers: modifiers)
    }

    public var effectiveMaxMana: Int {
        CombatantMaxValues.maxMana(for: combatant, modifiers: modifiers)
    }
}
