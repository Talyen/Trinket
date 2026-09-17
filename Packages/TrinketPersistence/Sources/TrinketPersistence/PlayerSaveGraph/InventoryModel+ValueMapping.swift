import Foundation
import os
import TrinketContent
import TrinketCore

/// Single logger for the inventory item codec (encode + decode).
let inventoryMappingLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "InventoryMapping",
)

/// Inventory item codec: `applyAffixPowers` (encode) lives beside
/// `restoredItem` (decode) so the drop-vs-fallback-vs-overwrite policy table
/// stays in one place. See `restoredItem` for the read policy.
extension InventoryItemModel {
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
        guard let baseType = ItemResolution.baseType(matching: item.baseTypeID, itemID: item.id) else {
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
                    isCorrupted: affix.isCorrupted,
                )
            }
        let affixPowers: [ItemAffixPower]? = {
            guard let data = item.affixPowersJSON else { return nil }
            do {
                return try ItemAffixPowerCoding.decode(data)
            } catch {
                inventoryMappingLogger.error(
                    "Failed to decode affix powers for inventory item \(item.id, privacy: .public): \(error.localizedDescription, privacy: .public)",
                )
                return nil
            }
        }()
        let persistedItem = InventoryItem(
            id: item.id,
            templateID: item.templateID,
            baseType: baseType,
            rarity: ItemResolution.rarity(matching: item.rarityID),
            displayName: item.displayName,
            affixes: affixes,
            isCorrupted: item.isCorrupted,
            affixPowers: affixPowers,
        )
        return ItemResolution.trinketAuthoritativeItem(
            persisted: persistedItem,
            baseSlot: baseType.slot,
            templateID: item.templateID,
        ) ?? persistedItem
    }
}
