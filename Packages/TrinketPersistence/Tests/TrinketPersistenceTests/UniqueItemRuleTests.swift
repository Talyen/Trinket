import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

/// Unique-item guarantees: durable ownership across save reload and
/// Corruption Altar exclusion. Salvage rejection lives in `ItemSalvageApplierTests`.
struct UniqueItemRuleTests {
    @Test @MainActor func uniqueSurvivesSaveRoundTripWithPinnedPowers() throws {
        let unique = try #require(GameContent.unique(matching: "wardbreaker"))
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        var save = store.currentSave
        save.inventory.items = [unique]
        try store.performBatchMutation { $0 = save }

        let reloaded = try PlayerSaveStore(
            storeURL: context.storeURL(),
            disableCloudSync: true
        )
        let restored = try #require(
            reloaded.inventory.items.first { $0.templateID == unique.templateID }
        )
        #expect(restored.rarity == .unique)
        #expect(restored.displayName == unique.displayName)
        #expect(restored.affixes == unique.affixes)
        #expect(restored.affixPowers == unique.affixPowers)
        #expect(reloaded.inventory.ownedUniqueIDs == [unique.templateID])
    }

    @Test func corruptionEligibilityExcludesUniques() {
        for item in GameContent.uniqueItems {
            #expect(!ItemCorruption.isEligibleTarget(item), Comment(rawValue: item.id))
        }
    }
}
