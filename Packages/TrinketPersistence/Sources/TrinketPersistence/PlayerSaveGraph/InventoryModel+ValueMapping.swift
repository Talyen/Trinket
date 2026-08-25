import Foundation
import os
import TrinketContent
import TrinketCore

extension InventoryModel {
    func toPlayerInventoryState() -> PlayerInventoryState {
        PlayerInventoryState(items: (items ?? [])
            .sorted { lhs, rhs in
                if lhs.sortIndex == rhs.sortIndex {
                    return lhs.id < rhs.id
                }
                return lhs.sortIndex < rhs.sortIndex
            }
            .compactMap(Self.restoredItem(from:)))
    }

    private static func restoredItem(from item: InventoryItemModel) -> InventoryItem? {
        guard let baseType = GameContent.itemBaseType(matching: item.baseTypeID) else {
            inventoryMappingLogger.error(
                "Dropping inventory item \(item.id, privacy: .public) with unknown base type \(item.baseTypeID, privacy: .public)"
            )
            return nil
        }
        let affixes = (item.affixes ?? [])
            .sorted { lhs, rhs in
                if lhs.sortIndex == rhs.sortIndex {
                    return lhs.id < rhs.id
                }
                return lhs.sortIndex < rhs.sortIndex
            }
            .compactMap { affix in
                let keywords = Set(affix.keywordRawValues.compactMap { Keyword(rawValue: $0) })
                return ItemAffix(
                    id: affix.id,
                    title: affix.title,
                    description: affix.affixDescription,
                    keywords: keywords,
                    isCorrupted: affix.isCorrupted
                )
            }
        let affixPowers: [ItemAffixPower]? = {
            guard let data = item.affixPowersJSON else { return nil }
            do {
                return try ItemAffixPowerCoding.decode(data)
            } catch {
                inventoryMappingLogger.error(
                    "Failed to decode affix powers for inventory item \(item.id, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                return nil
            }
        }()
        let persistedItem = InventoryItem(
            id: item.id,
            templateID: item.templateID,
            baseType: baseType,
            rarity: Rarity(rawValue: item.rarityID) ?? .basic,
            displayName: item.displayName,
            affixes: affixes,
            isCorrupted: item.isCorrupted,
            affixPowers: affixPowers
        )
        guard baseType.slot == .trinket,
              let authored = GameContent.itemTemplate(matching: item.templateID)
        else {
            return persistedItem
        }
        return InventoryItem(
            id: persistedItem.id,
            templateID: authored.templateID,
            baseType: authored.baseType,
            rarity: .astral,
            displayName: authored.displayName,
            affixes: authored.affixes
        )
    }
}
