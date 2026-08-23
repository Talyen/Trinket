import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

/// Unique-item guarantees: durable ownership across save reload, salvage
/// rejection, and Corruption Altar exclusion.
@MainActor
struct UniqueItemRuleTests {
    @Test func uniqueSurvivesSaveRoundTripWithPinnedPowers() throws {
        let unique = try #require(GameContent.unique(matching: "wardbreaker"))
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        var save = store.currentSave
        save.inventory.items = [unique]
        try store.performBatchMutation { $0 = save }

        let reloaded = store.currentSave
        let restored = try #require(
            reloaded.inventory.items.first { $0.templateID == unique.templateID }
        )
        #expect(restored.rarity == .unique)
        #expect(restored.displayName == "Wardbreaker")
        #expect(restored.affixes == unique.affixes)
        #expect(restored.affixPowers == unique.affixPowers)
        #expect(reloaded.inventory.ownedUniqueIDs == ["wardbreaker"])
    }

    @Test func salvageRejectsUniques() throws {
        let unique = try #require(GameContent.unique(matching: "bloodfire_signet"))
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        var save = store.currentSave
        save.inventory.items = [unique]
        try store.performBatchMutation { $0 = save }

        var result: ItemSalvageResult = .success(yields: [])
        try store.performBatchMutation { save in
            result = ItemSalvageApplier.salvage(itemID: unique.id, save: &save)
        }

        #expect(result == .ineligible)
        #expect(store.currentSave.inventory.items.contains { $0.id == unique.id })
    }

    @Test func corruptionEligibilityExcludesUniques() {
        for item in GameContent.uniqueItems {
            #expect(!ItemCorruption.isEligibleTarget(item), Comment(rawValue: item.id))
        }
    }
}
