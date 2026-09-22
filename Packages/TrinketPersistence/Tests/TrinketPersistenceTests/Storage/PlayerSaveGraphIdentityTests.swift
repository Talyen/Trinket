import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct PlayerSaveGraphIdentityTests {
    @Test @MainActor func `unrelated slice write preserves inventory and roster row identity`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let store = try context.makeReloadedStore()
        try store.applyTestSeed()
        let inspectionContext = try graphInspectionContext(at: storeURL)
        let before = try graphIdentity(in: inspectionContext)
        var homestead = store.homestead
        homestead.grant([ResourceAmount(.wood, 1)])

        #expect(store.persistBatch(logging: "Test setup") { $0.homestead = homestead })

        let after = try graphIdentity(in: inspectionContext)
        try #expect(after.inventoryItems == before.inventoryItems)
        try #expect(after.rosterProgressions == before.rosterProgressions)
    }

    @Test @MainActor func `inventory reconciliation preserves unchanged rows and ordering`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let store = try context.makeReloadedStore()
        try store.applyTestSeed()
        let inspectionContext = try graphInspectionContext(at: storeURL)
        let before = try graphIdentity(in: inspectionContext)
        var inventory = store.inventory
        let changedItem = try #require(inventory.items.first)
        let removedItem = try #require(inventory.items.last)
        inventory.items[0] = changedItem.renamed("\(changedItem.displayName) +1")
        inventory.items.removeLast()

        #expect(store.persistBatch(logging: "Test setup") { $0.inventory = inventory })

        let after = try graphIdentity(in: inspectionContext)
        try #expect(after.inventoryItems[changedItem.id] == before.inventoryItems[changedItem.id])
        try #expect(after.inventoryItems[removedItem.id] == nil)
        for item in inventory.items {
            try #expect(after.inventoryItems[item.id] == before.inventoryItems[item.id])
        }
        try #expect(after.rosterProgressions == before.rosterProgressions)

        let reloaded = try context.makeReloadedStore()
        try #expect(reloaded.inventory.items.map(\.id) == inventory.items.map(\.id))
        try #expect(reloaded.inventory.items.first?.displayName == "\(changedItem.displayName) +1")
    }

    @Test @MainActor func `inventory only mutation persists sanitized loadout removal`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let store = try context.makeReloadedStore()
        let item = try #require(GameContent.itemTemplate(matching: "shortsword-basic")).rewardInstance(
            for: "chapter-1-stage-1",
        )
        try store.performBatchMutation { save in
            save.inventory.items.append(item)
        }
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        var roster = store.roster
        var loadout = roster.equipmentLoadout(for: knight)
        loadout.equip(item, inventory: [item])
        roster.setEquipmentLoadout(loadout, for: knight)
        #expect(store.persistBatch(logging: "Test setup") { $0.roster = roster })

        #expect(store.persistBatch(logging: "Test setup") { $0.inventory = .freshStart })

        let slots = try graphInspectionContext(at: storeURL).fetch(FetchDescriptor<EquipmentSlotModel>())
        try #expect(slots.allSatisfy { $0.itemID != item.id })
    }

    private func graphInspectionContext(at storeURL: URL) throws -> ModelContext {
        try SaveTestSupport.makeSideContext(storeURL: storeURL)
    }

    private func graphIdentity(in modelContext: ModelContext) throws -> GraphIdentity {
        let inventoryItems = try modelContext.fetch(FetchDescriptor<InventoryItemModel>())
        let rosterProgressions = try modelContext.fetch(FetchDescriptor<CombatantProgressionModel>())
        return GraphIdentity(
            inventoryItems: Dictionary(uniqueKeysWithValues: inventoryItems.map {
                ($0.id, $0.persistentModelID)
            }),
            rosterProgressions: Dictionary(uniqueKeysWithValues: rosterProgressions.map {
                ($0.combatantID, $0.persistentModelID)
            }),
        )
    }
}

private struct GraphIdentity {
    let inventoryItems: [String: PersistentIdentifier]
    let rosterProgressions: [String: PersistentIdentifier]
}

private extension InventoryItem {
    func renamed(_ name: String) -> Self {
        Self(
            id: id,
            templateID: templateID,
            baseType: baseType,
            rarity: rarity,
            displayName: name,
            affixes: affixes,
            isCorrupted: isCorrupted,
            affixPowers: affixPowers,
        )
    }
}
