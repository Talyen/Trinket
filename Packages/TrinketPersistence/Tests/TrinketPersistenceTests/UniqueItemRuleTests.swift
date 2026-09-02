import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct UniqueItemRuleTests {
    @Test @MainActor func `unique survives save round trip with pinned powers`() throws {
        let unique = try #require(GameContent.unique(matching: "wardbreaker"))
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        var save = store.currentSave
        save.inventory.items = [unique]
        try store.performBatchMutation { $0 = save }

        let reloaded = try PlayerSaveStore(
            storeURL: context.storeURL(),
            disableCloudSync: true,
        )
        let restored = try #require(
            reloaded.inventory.items.first { $0.templateID == unique.templateID },
        )
        #expect(restored.rarity == .unique)
        #expect(restored.displayName == unique.displayName)
        #expect(restored.affixes == unique.affixes)
        #expect(restored.affixPowers == unique.affixPowers)
        #expect(reloaded.inventory.ownedUniqueIDs == [unique.templateID])
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

    @Test func `unique item cannot be purchased more than once in shop`() throws {
        let unique = try #require(GameContent.unique(matching: "wardbreaker"))
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 200)
        let firstOffer = ShopOffer(id: "unique-offer-a", item: unique, price: 30)
        let secondOffer = ShopOffer(id: "unique-offer-b", item: unique, price: 30)

        let first = ShopPurchaseApplier.purchase(
            offer: firstOffer,
            visitToken: "visit-a",
            stageID: "chapter-2-stage-8",
            save: &save,
        )
        let second = ShopPurchaseApplier.purchase(
            offer: secondOffer,
            visitToken: "visit-b",
            stageID: "chapter-2-stage-8",
            save: &save,
        )

        guard case let .success(purchased) = first else {
            Issue.record("Expected first unique purchase to succeed")
            return
        }
        #expect(purchased.id == unique.id)
        #expect(second == .alreadyOwned)
        #expect(save.roster.gold == 170)
        #expect(save.inventory.items == [unique])
    }
}
