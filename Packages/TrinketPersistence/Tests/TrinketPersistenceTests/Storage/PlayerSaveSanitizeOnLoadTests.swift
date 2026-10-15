import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct PlayerSaveSanitizeOnLoadTests {
    @Test @MainActor func `rejected primary shield does not reserve its valid secondary assignment`() throws {
        let context = try PersistenceTestContext()
        let shield = try SaveTestSupport.makeGeneratedItem(baseID: "kite_shield", rarity: .basic)
        var dirty = PlayerSave.testSeed
        dirty.inventory = PlayerInventoryState(items: [shield])
        dirty.roster.equipmentLoadouts = [
            "knight": EquipmentLoadout(itemIDsBySlot: [.weapon: shield.id, .secondaryWeapon: shield.id]),
        ]
        try SaveTestSupport.writeRoot(dirty, to: context.storeURL())

        let store = try context.makeReloadedStore()
        #expect(store.roster.equipmentLoadouts["knight"]?.itemID(for: .weapon) == nil)
        #expect(store.roster.equipmentLoadouts["knight"]?.itemID(for: .secondaryWeapon) == shield.id)
        let repaired = store.roster
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster == repaired)
    }

    @Test @MainActor func `repairing shared bows removes dependent quivers before publication`() throws {
        let context = try PersistenceTestContext()
        let bow = try #require(PlayerInventoryState.testSeed.item(matching: "longbow-basic"))
        let quiver = try SaveTestSupport.makeGeneratedItem(baseID: "quiver", rarity: .basic)
        var dirty = PlayerSave.testSeed
        dirty.inventory = PlayerInventoryState(items: [bow, quiver])
        dirty.roster.equipmentLoadouts = [
            "knight": EquipmentLoadout(itemIDsBySlot: [.weapon: bow.id]),
            "wizard": EquipmentLoadout(itemIDsBySlot: [.weapon: bow.id, .secondaryWeapon: quiver.id]),
        ]
        try SaveTestSupport.writeRoot(dirty, to: context.storeURL())

        let store = try context.makeReloadedStore()
        #expect(store.roster.equipmentLoadouts["knight"]?.itemID(for: .weapon) == bow.id)
        #expect(store.roster.equipmentLoadouts["wizard"]?.itemID(for: .weapon) == nil)
        #expect(store.roster.equipmentLoadouts["wizard"]?.itemID(for: .secondaryWeapon) == nil)
        #expect(store.inventory.item(matching: quiver.id) == quiver)
        let repaired = store.roster
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster == repaired)
    }

    @Test @MainActor func `ensure required graph persists semantic sanitize diffs`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        var dirty = PlayerSave.testSeed
        dirty.homestead.resources[.wood] = -12
        dirty.roster.equipmentLoadouts["knight"] = EquipmentLoadout(
            itemIDsBySlot: [.weapon: "ghost-sword"],
        )

        try SaveTestSupport.writeRoot(dirty, to: storeURL)

        let store = try context.makeReloadedStore()
        try #expect(store.homestead.resources[.wood] == 0)
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        try #expect(store.roster.equipmentLoadout(for: knight).itemID(for: .weapon) == nil)

        var journey = store.journey
        let stageID = try #require(GameContent.chapters.first?.stages.first?.id)
        journey.completedStageIDs.insert(stageID)
        #expect(store.persistFixtureBatch(logging: "Test setup") { $0.journey = journey })
        try #expect(store.journey.completedStageIDs.contains(stageID))
        try #expect(store.lastPersistenceError == nil)

        let sideContext = try SaveTestSupport.makeSideContext(storeURL: storeURL)
        let balances = try sideContext.fetch(FetchDescriptor<HomesteadResourceBalanceModel>())
        let wood = balances.first { $0.resourceID == HomesteadResource.wood.rawValue }
        try #expect(wood == nil || wood?.quantity == 0)

        let slots = try sideContext.fetch(FetchDescriptor<EquipmentSlotModel>())
        try #expect(slots.allSatisfy { $0.itemID != "ghost-sword" })
    }
}
