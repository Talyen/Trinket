import Foundation

public extension GameContent {
    static let traits: [CombatantTraitDefinition] = GameContentTraits.definitions
    static let combatantTraitIDs: [String: String] = GameContentRosterGenerated.combatantTraitIDs

    static func trait(forCombatantID combatantID: String) -> CombatantTraitDefinition? {
        guard let traitID = combatantTraitIDs[combatantID] else { return nil }
        return trait(id: traitID)
    }

    static func trait(id: String) -> CombatantTraitDefinition? {
        traits.first { $0.id == id }
    }

    static func trait(for enemy: Enemy) -> CombatantTraitDefinition? {
        trait(id: enemy.traitID)
    }

    static func traits(for enemy: Enemy) -> [CombatantTraitDefinition] {
        [trait(for: enemy)].compactMap(\.self)
    }
}

enum GameContentTraits {
    static let definitions: [CombatantTraitDefinition] = GameContentTraitsGenerated.definitions
}
