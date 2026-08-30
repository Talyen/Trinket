import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@MainActor
final class PlayerSaveGraphIdentityTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func `unrelated slice write preserves inventory and roster row identity`() throws {
        let storeURL = context.storeURL()
        let store = try makeStore(at: storeURL)
        try store.applyTestSeed()
        let inspectionContext = try graphInspectionContext(at: storeURL)
        let before = try graphIdentity(in: inspectionContext)
        var homestead = store.homestead
        homestead.grant([ResourceAmount(.wood, 1)])

        store.homestead = homestead

        let after = try graphIdentity(in: inspectionContext)
        try #expect(after.inventoryItems == before.inventoryItems)
        try #expect(after.rosterProgressions == before.rosterProgressions)
    }

    @Test func `inventory reconciliation preserves unchanged rows and ordering`() throws {
        let storeURL = context.storeURL()
        let store = try makeStore(at: storeURL)
        try store.applyTestSeed()
        let inspectionContext = try graphInspectionContext(at: storeURL)
        let before = try graphIdentity(in: inspectionContext)
        var inventory = store.inventory
        let changedItem = try #require(inventory.items.first)
        let removedItem = try #require(inventory.items.last)
        inventory.items[0] = changedItem.renamed("\(changedItem.displayName) +1")
        inventory.items.removeLast()

        store.inventory = inventory

        let after = try graphIdentity(in: inspectionContext)
        try #expect(after.inventoryItems[changedItem.id] == before.inventoryItems[changedItem.id])
        try #expect(after.inventoryItems[removedItem.id] == nil)
        for item in inventory.items {
            try #expect(after.inventoryItems[item.id] == before.inventoryItems[item.id])
        }
        try #expect(after.rosterProgressions == before.rosterProgressions)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.inventory.items.map(\.id) == inventory.items.map(\.id))
        try #expect(reloaded.inventory.items.first?.displayName == "\(changedItem.displayName) +1")
    }

    @Test func `inventory only mutation persists sanitized loadout removal`() throws {
        let storeURL = context.storeURL()
        let store = try makeStore(at: storeURL)
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
        store.roster = roster

        store.inventory = .freshStart

        let slots = try graphInspectionContext(at: storeURL).fetch(FetchDescriptor<EquipmentSlotModel>())
        try #expect(slots.allSatisfy { $0.itemID != item.id })
    }

    private func makeStore(at storeURL: URL) throws -> PlayerSaveStore {
        try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true,
        )
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
