import Foundation

public extension GameContent {
    public static let traits: [CombatantTraitDefinition] = GameContentTraits.definitions
    public static let combatantTraitIDs: [String: String] = GameContentRosterGenerated.combatantTraitIDs

    public static func trait(forCombatantID combatantID: String) -> CombatantTraitDefinition? {
        guard let traitID = combatantTraitIDs[combatantID] else { return nil }
        return trait(id: traitID)
    }

    public static func trait(id: String) -> CombatantTraitDefinition? {
        traits.first { $0.id == id }
    }

    public static func positiveTrait(for enemy: Enemy) -> CombatantTraitDefinition? {
        trait(id: enemy.positiveTraitID)
    }

    public static func negativeTrait(for enemy: Enemy) -> CombatantTraitDefinition? {
        trait(id: enemy.negativeTraitID)
    }

    public static func traits(for enemy: Enemy) -> [CombatantTraitDefinition] {
        [positiveTrait(for: enemy), negativeTrait(for: enemy)].compactMap(\.self)
    }
}

enum GameContentTraits {
    static let definitions: [CombatantTraitDefinition] = GameContentTraitsGenerated.definitions
}
