import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct HomesteadActivityStoreTests {
    @Test @MainActor func `conversion inscription and wish survive refused writes reload and snapshot codecs`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let base = try #require(GameContent.itemBaseType(matching: "leather_armor"))
        var random = SeededRandomNumberGenerator(seed: 17)
        let item = ItemGenerator().generate(id: "durable-inscription", baseType: base, rarity: .basic, fixedAffixCount: 2, using: &random)
        let target = try #require(GameContent.uniqueItems.first)
        try store.performFixtureMutation { save in
            save.inventory.items = [item]
            save.roster.gold = 50
            save.homestead = PlayerHomesteadState(
                resources: [.iron: 100, .gems: 100],
                nodeTiers: [.transmutationCrucible: 1, .runesmithWorkshop: 1, .wishingWell: 1],
            )
        }
        store.forcesNextSaveFailure = true
        _ = try await store.transmuteResource(from: .gold, to: .wood, quantity: 10).get()
        let afterConversion = try context.makeReloadedStore()
        #expect(afterConversion.roster.gold == 40 && afterConversion.homestead.resources[.wood] == 10)
        store.forcesNextSaveFailure = true
        let inscribed = try await store.inscribeItem(itemID: item.id, index: 0, affixID: item.affixes[0].id).get()
        #expect(inscribed.inscribedAffixIndex == 0)
        #expect(store.homestead.resources[.iron] == 92 && store.homestead.resources[.gems] == 96)
        let first = store.currentSave
        await #expect(throws: HomesteadActivityFailure.self) {
            try await store.inscribeItem(itemID: item.id, index: 1, affixID: item.affixes[1].id).get()
        }
        #expect(store.currentSave == first)
        _ = try await store.setItemWish(target.templateID).get()
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.inventory.items == [inscribed])
        #expect(reloaded.homestead.wishedTemplateID == target.templateID)
        let snapshot = PlayerSaveSnapshot(reloaded.currentSave)
        let decoded = try JSONDecoder().decode(PlayerSaveSnapshot.self, from: JSONEncoder().encode(snapshot)).decodedSave()
        #expect(decoded.inventory.items == [inscribed])
        #expect(decoded.homestead.wishedTemplateID == target.templateID)
        try store.performFixtureMutation { $0.inventory.items.append(target) }
        #expect(store.homestead.wishedTemplateID == nil)
        #expect(try context.makeReloadedStore().homestead.wishedTemplateID == nil)
    }

    @Test @MainActor func `outfitter craft spends materials and survives reload`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        try store.performFixtureMutation { save in
            save.inventory.items = []
            save.homestead = PlayerHomesteadState(resources: [.hide: 100, .wood: 100], nodeTiers: [.woolTailoring: 1])
        }
        let item = try await store.craftEquipmentItem(recipeID: "outfitter-leather-armor").get()
        let reloaded = try context.makeReloadedStore()
        #expect(item.baseType.id == "leather_armor" && !item.isTrinket)
        #expect(reloaded.inventory.items == [item])
        #expect(reloaded.homestead.resources[.hide] == 60 && reloaded.homestead.resources[.wood] == 80)
    }

    @Test @MainActor func `distributed library graph migrates without losing inventory or building state`() throws {
        let context = try PersistenceTestContext()
        try autoreleasepool {
            let schema = Schema(versionedSchema: PlayerSaveSchemaV4.self)
            let container = try SaveTestSupport.makeContainer(storeURL: context.storeURL(), schema: schema)
            let root = PlayerSaveSchemaV4.PlayerSaveRoot()
            root.worldSeed = PlayerSave.testWorldSeed
            let homestead = PlayerSaveSchemaV4.HomesteadModel()
            let tier = PlayerSaveSchemaV4.HomesteadNodeTierModel(nodeID: "woolTailoring", tier: 3)
            tier.homestead = homestead
            homestead.nodeTiers = [tier]
            homestead.root = root
            root.homestead = homestead
            let inventory = PlayerSaveSchemaV4.InventoryModel()
            let item = PlayerSaveSchemaV4.InventoryItemModel()
            item.id = "old-leather"
            item.templateID = "leather_armor-basic"
            item.baseTypeID = "leather_armor"
            item.rarityID = Rarity.basic.rawValue
            item.displayName = "Leather Armor"
            item.inventory = inventory
            inventory.items = [item]
            inventory.root = root
            root.inventory = inventory
            root.libraryPayload = try PlayerLibraryState().encodedPayload()
            let modelContext = ModelContext(container)
            modelContext.insert(root)
            try modelContext.save()
        }
        let migrated = try context.makeReloadedStore()
        #expect(migrated.homestead.tier(for: .woolTailoring) == 3)
        #expect(migrated.homestead.wishedTemplateID == nil)
        #expect(migrated.inventory.items.first?.id == "old-leather")
        #expect(migrated.inventory.items.first?.inscribedAffixIndex == nil)
        #expect(migrated.currentSave.schemaVersion == PlayerSave.currentSchemaVersion)
        var oldSnapshot = PlayerSaveSnapshot(migrated.currentSave)
        oldSnapshot.schemaVersion = 19
        let restored = try oldSnapshot.decodedSave()
        #expect(restored.schemaVersion == PlayerSave.currentSchemaVersion)
        #expect(restored.inventory == migrated.inventory)
        #expect(restored.homestead == migrated.homestead)
    }
}

extension HomesteadActivityStoreTests {
    @Test @MainActor func `converting capped gold cannot reopen past production credit`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let start = Date(timeIntervalSince1970: 0)
        let conversionDate = start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        try store.performFixtureMutation { save in
            save.roster.gold = GoldBalance.maximum
            save.homestead = PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.transmutationCrucible: 1, .wishingWell: 4],
                lastProductionAt: start,
            )
        }
        _ = try await store.transmuteResource(from: .gold, to: .wood, quantity: 10, at: conversionDate).get()
        #expect(await store.collectProduction(at: conversionDate) == .success([ResourceAmount(.iron, 1)]))
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == GoldBalance.maximum - 10)
        #expect(reloaded.homestead.resources[.wood] == 10)
    }
}
