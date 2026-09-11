import Foundation
import TrinketCore

public enum GameContent {
    public static let itemBaseTypes: [ItemBaseType] = GameContentItemBasesGenerated.itemBaseTypes
    public static let itemAffixDefinitions: [ItemAffixDefinition] = ItemAffixCatalog.definitions

    private static let itemBaseTypesByID = Dictionary(
        uniqueKeysWithValues: itemBaseTypes.map { ($0.id, $0) },
    )

    private static let itemAffixDefinitionsByID = Dictionary(
        uniqueKeysWithValues: itemAffixDefinitions.map { ($0.id, $0) },
    )

    public static func itemBaseType(matching id: String) -> ItemBaseType? {
        itemBaseTypesByID[id]
    }

    public static func itemAffixDefinition(matching id: String) -> ItemAffixDefinition? {
        itemAffixDefinitionsByID[id]
    }

    public static func stableSeed(for text: String) -> UInt64 {
        text.utf8.reduce(14695981039346656037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1099511628211
        }
    }

    public static func encounterSeed(_ worldSeed: UInt64, salt: String) -> UInt64 {
        worldSeed &+ stableSeed(for: salt)
    }
}
