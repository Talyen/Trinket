import Foundation
import TrinketCore

public extension GameContent {
    internal static let traits: [CombatantTraitDefinition] = GameContentTraitsGenerated.definitions
    private static let traitsByID: [String: CombatantTraitDefinition] = Dictionary(
        uniqueKeysWithValues: traits.map { ($0.id, $0) },
    )

    static func trait(id: String) -> CombatantTraitDefinition? {
        traitsByID[id]
    }

    static func traits(for enemy: Enemy) -> [CombatantTraitDefinition] {
        enemy.traitIDs.compactMap { trait(id: $0) }
    }
}
