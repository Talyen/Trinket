import Foundation

public extension GameContent {
    internal static let traits: [CombatantTraitDefinition] = GameContentTraits.definitions

    static func trait(id: String) -> CombatantTraitDefinition? {
        traits.first { $0.id == id }
    }

    static func trait(for enemy: Enemy) -> CombatantTraitDefinition? {
        trait(id: enemy.traitID)
    }
}

enum GameContentTraits {
    static let definitions: [CombatantTraitDefinition] = GameContentTraitsGenerated.definitions
}
