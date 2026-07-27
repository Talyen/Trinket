import Foundation
import SwiftData
import TrinketContent
import TrinketCore

@Model
public final class InventoryModel {
    public var root: PlayerSaveRoot?

    @Relationship(deleteRule: .cascade, inverse: \InventoryItemModel.inventory)
    public var items: [InventoryItemModel]?

    public init() {}
}

@Model
public final class InventoryItemModel {
    public var id: String = ""
    public var templateID: String = ""
    public var baseTypeID: String = ""
    public var rarityID: String = Rarity.basic.rawValue
    public var displayName: String = ""
    public var sortIndex: Int = 0
    public var isCorrupted: Bool = false
    public var affixPowersJSON: Data?
    public var inventory: InventoryModel?

    @Relationship(deleteRule: .cascade, inverse: \ItemAffixModel.item)
    public var affixes: [ItemAffixModel]?

    public init() {}

    public init(item: InventoryItem) {
        id = item.id
        templateID = item.templateID
        baseTypeID = item.baseType.id
        rarityID = item.rarity.rawValue
        displayName = item.displayName
        isCorrupted = item.isCorrupted
        if let powers = item.affixPowers {
            affixPowersJSON = try? ItemAffixPowerCoding.encode(powers)
        } else {
            affixPowersJSON = nil
        }
        affixes = item.affixes.enumerated().map { index, affix in
            let model = ItemAffixModel(affix: affix)
            model.sortIndex = index
            return model
        }
    }
}

@Model
public final class ItemAffixModel {
    public var id: String = ""
    public var title: String = ""
    public var affixDescription: String = ""
    public var keywordRawValues: [String] = []
    public var sortIndex: Int = 0
    public var item: InventoryItemModel?

    public init() {}

    public init(affix: ItemAffix) {
        id = affix.id
        title = affix.title
        affixDescription = affix.description
        keywordRawValues = affix.keywords.map(\.rawValue).sorted()
    }
}
