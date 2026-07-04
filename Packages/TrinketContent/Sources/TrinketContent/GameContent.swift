import Foundation
import TrinketCore

public enum GameContent {
    public static let itemBaseTypes: [ItemBaseType] = GameContentItemBasesGenerated.itemBaseTypes
    public static let itemAffixDefinitions: [ItemAffixDefinition] = ItemAffixCatalog.definitions
}
