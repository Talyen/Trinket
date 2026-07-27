import Foundation
import TrinketCore

public struct InventoryItem: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let templateID: String
    public let baseType: ItemBaseType
    public let rarity: Rarity
    public let displayName: String
    public let affixes: [ItemAffix]
    /// Once true, the item cannot be corrupted again.
    public let isCorrupted: Bool
    /// When non-nil, authoritative combat/UI powers (same order as `affixes`).
    public let affixPowers: [ItemAffixPower]?

    public init(
        id: String,
        templateID: String? = nil,
        baseType: ItemBaseType,
        rarity: Rarity,
        displayName: String,
        affixes: [ItemAffix],
        isCorrupted: Bool = false,
        affixPowers: [ItemAffixPower]? = nil
    ) {
        self.id = id
        self.templateID = templateID ?? id
        self.baseType = baseType
        self.rarity = rarity
        self.displayName = displayName
        self.affixes = affixes
        self.isCorrupted = isCorrupted
        self.affixPowers = affixPowers
    }

    public func rewardInstance(for stageID: String) -> InventoryItem {
        InventoryItem(
            id: "\(stageID)-\(templateID)",
            templateID: templateID,
            baseType: baseType,
            rarity: rarity,
            displayName: displayName,
            affixes: affixes,
            isCorrupted: isCorrupted,
            affixPowers: affixPowers
        )
    }

    /// Resolved power for an affix index — instance override when present, else catalog.
    public func resolvedPower(at affixIndex: Int) -> ItemAffixPower? {
        if let affixPowers, affixPowers.indices.contains(affixIndex) {
            return affixPowers[affixIndex]
        }
        guard affixes.indices.contains(affixIndex),
              let definition = GameContent.itemAffixDefinition(matching: affixes[affixIndex].id)
        else {
            return nil
        }
        return definition.power(for: rarity)
    }
}

public struct EquipmentLoadout: Equatable, Hashable, Sendable {
    public var itemIDsBySlot: [ItemSlot: String]

    public init(itemIDsBySlot: [ItemSlot: String] = [:]) {
        self.itemIDsBySlot = itemIDsBySlot
    }

    public func itemID(for slot: ItemSlot) -> String? {
        itemIDsBySlot[slot]
    }

    public mutating func equip(_ item: InventoryItem, in slot: ItemSlot? = nil) {
        let destination = slot ?? item.baseType.slot
        // One inventory instance can occupy only one slot; moving re-equips.
        for occupied in ItemSlot.allCases where occupied != destination {
            if itemIDsBySlot[occupied] == item.id {
                itemIDsBySlot[occupied] = nil
            }
        }
        itemIDsBySlot[destination] = item.id
    }

    public mutating func unequip(_ slot: ItemSlot) {
        itemIDsBySlot[slot] = nil
    }
}
