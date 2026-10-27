import Foundation
import os
import SwiftData
import TrinketContent
import TrinketCore

/// Diagnostics for unreadable inventory values.
let inventoryMappingLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "InventoryMapping",
)

extension InventoryModel {
    func toPlayerInventoryState() -> PlayerInventoryState {
        PlayerInventoryState(items: (items ?? [])
            .sorted { ($0.sortIndex, $0.id) < ($1.sortIndex, $1.id) }
            .compactMap(Self.restoredItem(from:)))
    }

    private static func restoredItem(from item: InventoryItemModel) -> InventoryItem? {
        guard let baseType = ItemResolution.baseType(matching: item.baseTypeID, itemID: item.id) else {
            return nil
        }
        let affixes = (item.affixes ?? [])
            .sorted { ($0.sortIndex, $0.id) < ($1.sortIndex, $1.id) }
            .map { $0.toItemAffix() }
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
            inscribedAffixIndex: item.inscribedAffixIndex,
        )
        return ItemResolution.trinketAuthoritativeItem(
            persisted: persistedItem,
            baseSlot: baseType.slot,
            templateID: item.templateID,
        ) ?? persistedItem
    }
}

extension InventoryItemModel {
    func update(from item: InventoryItem, powerPayload: Data?, context: ModelContext?) {
        id = item.id
        templateID = item.templateID
        baseTypeID = item.baseType.id
        rarityID = item.rarity.rawValue
        displayName = item.displayName
        isCorrupted = item.isCorrupted
        affixPowersJSON = powerPayload
        inscribedAffixIndex = item.inscribedAffixIndex
        affixes = reconcileModels(
            existing: affixes ?? [],
            values: item.affixes.indices.lazy.map { (offset: $0, element: item.affixes[$0]) },
            existingKey: \.id,
            valueKey: { $0.element.id },
            make: { ItemAffixModel() },
            update: { model, value in
                model.update(from: value.element)
                model.sortIndex = value.offset
            },
            link: { $0.item = self },
            context: context,
        )
    }
}

extension ItemAffixModel {
    func toItemAffix() -> ItemAffix {
        ItemAffix(
            id: id,
            title: title,
            description: affixDescription,
            keywords: Set(keywordRawValues.lazy.compactMap { Keyword(rawValue: $0) }),
            isCorrupted: isCorrupted,
        )
    }

    func update(from affix: ItemAffix) {
        id = affix.id
        title = affix.title
        affixDescription = affix.description
        keywordRawValues = affix.keywords.lazy.map(\.rawValue).sorted()
        isCorrupted = affix.isCorrupted
    }
}

extension InventoryModel {
    /// ID upsert only. Trinket/unique-template uniqueness is enforced upstream
    /// by `PlayerSaveSanitizer` (`InventoryDuplicatePolicy.deduplicated`) and
    /// detected on load by `repairSlices`; reconcile must not drop rows with
    /// distinct IDs or a sanitize-then-write round trip would diverge.
    func update(from inventory: PlayerInventoryState, powerPayloads: [String: Data], context: ModelContext?) {
        items = reconcileModels(
            existing: items ?? [],
            values: inventory.items.indices.lazy.map { (offset: $0, element: inventory.items[$0]) },
            existingKey: \.id,
            valueKey: { $0.element.id },
            make: { InventoryItemModel() },
            update: { model, value in
                model.update(from: value.element, powerPayload: powerPayloads[value.element.id], context: context)
                model.sortIndex = value.offset
            },
            link: { $0.inventory = self },
            context: context,
        )
    }
}
