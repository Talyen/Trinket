import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct UniqueItemRuleTests {
    @Test @MainActor func `unique survives save round trip with pinned powers`() throws {
        let uniques = GameContent.uniqueItems
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        var save = store.currentSave
        save.inventory.items = uniques
        save.roster.equipmentLoadouts["knight"] = EquipmentLoadout(itemIDsBySlot: [.weapon: "oathkeeper"])
        try store.performBatchMutation { $0 = save }

        let reloaded = try PlayerSaveStore(
            storeURL: context.storeURL(),
            disableCloudSync: true,
        )
        for unique in uniques {
            let restored = try #require(reloaded.inventory.items.first { $0.templateID == unique.templateID })
            #expect(restored.rarity == .unique)
            #expect(restored.displayName == unique.displayName)
            #expect(restored.affixes == unique.affixes)
            #expect(restored.affixPowers == unique.affixPowers)
        }
        #expect(reloaded.inventory.ownedUniqueIDs == Set(uniques.map(\.templateID)))
        #expect(reloaded.roster.equipmentLoadouts["knight"]?.itemID(for: .weapon) == "oathkeeper")
    }

    @Test func `corruption eligibility excludes uniques`() {
        for item in GameContent.uniqueItems {
            #expect(!ItemCorruption.isEligibleTarget(item), Comment(rawValue: item.id))
        }
    }

    @Test func `unique items are deduplicated and rejected when duplicate exists`() throws {
        let unique = try #require(GameContent.unique(matching: "wardbreaker"))
        let duplicateWithNewID = InventoryItem(
            id: "copy-wardbreaker",
            templateID: unique.templateID,
            baseType: unique.baseType,
            rarity: unique.rarity,
            displayName: unique.displayName,
            affixes: unique.affixes,
            isCorrupted: unique.isCorrupted,
            affixPowers: unique.affixPowers,
        )
        #expect(InventoryDuplicatePolicy.isDuplicate(unique, duplicateWithNewID))

        var inventory = PlayerInventoryState(items: [unique])
        inventory.appendUniqueItem(duplicateWithNewID)
        #expect(inventory.items.count == 1)

        let sanitized = PlayerSaveSanitizer.sanitizeInventory(
            PlayerInventoryState(items: [unique, duplicateWithNewID]),
        )
        #expect(sanitized.items.count == 1)
        #expect(sanitized.items.first?.id == unique.id)
    }

    @Test func `persisted trinket refreshes from authored catalog`() throws {
        let staleItem = InventoryItemModel()
        staleItem.id = "owned-meteorite"
        staleItem.templateID = "meteorite"
        staleItem.baseTypeID = "meteorite"
        staleItem.rarityID = Rarity.basic.rawValue
        staleItem.displayName = "Dormant Meteorite"
        staleItem.affixes = [ItemAffixModel(affix: ItemAffix(
            id: "dormant_meteorite",
            title: "Dormant",
            description: "Placeholder.",
            keywords: [.burn],
        ))]
        let model = InventoryModel()
        model.items = [staleItem]

        let restored = try #require(model.toPlayerInventoryState().items.first)
        let authored = try #require(GameContent.itemTemplate(matching: "meteorite"))

        #expect(restored.id == "owned-meteorite")
        #expect(restored.rarity == .astral)
        #expect(restored.displayName == authored.displayName)
        #expect(restored.affixes == authored.affixes)
    }
}
