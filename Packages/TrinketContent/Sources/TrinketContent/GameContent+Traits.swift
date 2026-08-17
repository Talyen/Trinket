import Foundation

public extension GameContent {
    static let traits: [CombatantTraitDefinition] = GameContentTraits.definitions

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
