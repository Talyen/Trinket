import Foundation
import TrinketCore

public enum GameContent {
    public static let itemBaseTypes: [ItemBaseType] = GameContentItemBasesGenerated.itemBaseTypes
    public static let itemAffixDefinitions: [ItemAffixDefinition] = ItemAffixCatalog.definitions

    private static let itemBaseTypesByID = Dictionary(
        uniqueKeysWithValues: itemBaseTypes.map { ($0.id, $0) }
    )

    private static let itemAffixDefinitionsByID = Dictionary(
        uniqueKeysWithValues: itemAffixDefinitions.map { ($0.id, $0) }
    )

    public static func itemBaseType(matching id: String) -> ItemBaseType? {
        itemBaseTypesByID[id]
    }

    public static func itemAffixDefinition(matching id: String) -> ItemAffixDefinition? {
        itemAffixDefinitionsByID[id]
    }
}
