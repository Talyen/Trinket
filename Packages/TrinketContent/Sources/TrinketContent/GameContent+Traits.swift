import Foundation

public extension GameContent {
    public static let traits: [CombatantTraitDefinition] = GameContentTraits.definitions
    public static let combatantTraitIDs: [String: String] = GameContentRosterGenerated.combatantTraitIDs

    public static func trait(forCombatantID combatantID: String) -> CombatantTraitDefinition? {
        guard let traitID = combatantTraitIDs[combatantID] else { return nil }
        return traits.first { $0.id == traitID }
    }
}

public enum GameContentTraits {
    public static let definitions: [CombatantTraitDefinition] = GameContentTraitsGenerated.definitions
}
