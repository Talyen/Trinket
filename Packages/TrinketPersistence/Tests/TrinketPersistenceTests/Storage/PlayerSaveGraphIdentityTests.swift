import SwiftData
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct PlayerSaveGraphIdentityTests {
    @Test @MainActor func `unrelated slice write preserves inventory and roster row identity`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeReloadedStore()
        try store.applyTestSeed()
        let before = try GraphIdentity(context)
        var homestead = store.homestead
        homestead.grant([ResourceAmount(.wood, 1)])

        #expect(store.persistBatch(logging: "Test setup") { $0.homestead = homestead })

        try #expect(GraphIdentity(context) == before)
    }

    @Test @MainActor func `inventory reconciliation preserves unchanged rows and ordering`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeReloadedStore()
        try store.applyTestSeed()
        let before = try GraphIdentity(context)
        var inventory = store.inventory
        try #require(Set(before.inventoryItems.keys) == Set(inventory.items.map(\.id)))
        let changedItem = try #require(inventory.items.first)
        let removedItem = try #require(inventory.items.last)
        try #require(changedItem.id != removedItem.id)
        inventory.items[0] = changedItem.renamed("\(changedItem.displayName) +1")
        inventory.items.removeLast()

        #expect(store.persistBatch(logging: "Test setup") { $0.inventory = inventory })

        let after = try GraphIdentity(context)
        let survivingRows = before.inventoryItems.filter { $0.key != removedItem.id }
        try #expect(after.inventoryItems == survivingRows)
        try #expect(after.rosterProgressions == before.rosterProgressions)

        let reloaded = try context.makeReloadedStore()
        try #expect(reloaded.inventory.items.map(\.id) == inventory.items.map(\.id))
        try #expect(reloaded.inventory.items.first?.displayName == "\(changedItem.displayName) +1")
    }

    @Test @MainActor func `inventory only mutation persists sanitized loadout removal`() throws {
        let context = try PersistenceTestContext()
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
        let equippedSlots = try context.makeSideContext().fetch(FetchDescriptor<EquipmentSlotModel>())
        try #require(equippedSlots.contains { $0.itemID == item.id })

        #expect(store.persistBatch(logging: "Test setup") { $0.inventory = .freshStart })

        let slots = try context.makeSideContext().fetch(FetchDescriptor<EquipmentSlotModel>())
        try #expect(slots.allSatisfy { $0.itemID != item.id })
        let reloaded = try context.makeReloadedStore()
        try #expect(reloaded.inventory.items.isEmpty)
        try #expect(reloaded.roster.equipmentLoadout(for: knight).itemID(for: .weapon) == nil)
    }
}

private struct GraphIdentity: Equatable {
    let inventoryItems: [String: PersistentIdentifier]
    let rosterProgressions: [String: PersistentIdentifier]

    init(_ context: PersistenceTestContext) throws {
        let modelContext = try context.makeSideContext()
        let inventoryItems = try modelContext.fetch(FetchDescriptor<InventoryItemModel>())
        let rosterProgressions = try modelContext.fetch(FetchDescriptor<CombatantProgressionModel>())
        try #require(!inventoryItems.isEmpty)
        try #require(!rosterProgressions.isEmpty)
        self.inventoryItems = Dictionary(uniqueKeysWithValues: inventoryItems.map { ($0.id, $0.persistentModelID) })
        self.rosterProgressions = Dictionary(uniqueKeysWithValues: rosterProgressions.map { ($0.combatantID, $0.persistentModelID) })
    }
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
