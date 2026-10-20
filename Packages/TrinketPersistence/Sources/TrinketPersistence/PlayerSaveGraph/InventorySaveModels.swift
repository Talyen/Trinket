import Foundation
import SwiftData
import TrinketContent
import TrinketCore

@Model
final class InventoryModel {
    var root: PlayerSaveRoot?

    @Relationship(deleteRule: .cascade, inverse: \InventoryItemModel.inventory)
    var items: [InventoryItemModel]?

    init() {}
}

@Model
final class InventoryItemModel {
    var id: String = ""
    var templateID: String = ""
    var baseTypeID: String = ""
    var rarityID: String = Rarity.basic.rawValue
    var displayName: String = ""
    var sortIndex: Int = 0
    var isCorrupted: Bool = false
    var affixPowersJSON: Data?
    var inscribedAffixIndex: Int?
    var inventory: InventoryModel?

    @Relationship(deleteRule: .cascade, inverse: \ItemAffixModel.item)
    var affixes: [ItemAffixModel]?

    init() {}
}

@Model
final class ItemAffixModel {
    var id: String = ""
    var title: String = ""
    var affixDescription: String = ""
    var keywordRawValues: [String] = []
    var isCorrupted: Bool = false
    var sortIndex: Int = 0
    var item: InventoryItemModel?

    init() {}

    convenience init(affix: ItemAffix) {
        self.init()
        update(from: affix)
    }
}
