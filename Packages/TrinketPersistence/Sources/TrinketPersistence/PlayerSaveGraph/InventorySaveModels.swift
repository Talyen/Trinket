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

    public convenience init(item: InventoryItem) {
        self.init()
        updateWithoutContext(from: item)
    }

    func applyAffixPowers(from item: InventoryItem) {
        if let powers = item.affixPowers {
            do {
                affixPowersJSON = try ItemAffixPowerCoding.encode(powers)
            } catch {
                inventoryMappingLogger.error(
                    "Failed to encode affix powers for inventory item \(item.id, privacy: .public): \(error.localizedDescription, privacy: .public)",
                )
                affixPowersJSON = nil
            }
        } else {
            affixPowersJSON = nil
        }
    }
}

@Model
public final class ItemAffixModel {
    public var id: String = ""
    public var title: String = ""
    public var affixDescription: String = ""
    public var keywordRawValues: [String] = []
    public var isCorrupted: Bool = false
    public var sortIndex: Int = 0
    public var item: InventoryItemModel?

    public init() {}

    public init(affix: ItemAffix) {
        id = affix.id
        title = affix.title
        affixDescription = affix.description
        keywordRawValues = affix.keywords.map(\.rawValue).sorted()
        isCorrupted = affix.isCorrupted
    }
}
