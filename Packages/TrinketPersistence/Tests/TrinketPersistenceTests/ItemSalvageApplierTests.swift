import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct ItemSalvageApplierTests {
    @Test func yieldsMatchSlotAndRarityTable() throws {
        let basicWeapon = try SaveTestSupport.makeGeneratedItem(baseID: "longsword", rarity: .basic)
        let astralTrinket = try SaveTestSupport.makeGeneratedItem(baseID: "sapphire_ring", rarity: .astral)
        let basicArmor = try SaveTestSupport.makeGeneratedItem(baseID: "leather_armor", rarity: .basic)

        #expect(ItemSalvage.yields(for: basicWeapon) == [
            ResourceAmount(.iron, 8),
            ResourceAmount(.wood, 4),
        ])
        #expect(ItemSalvage.yields(for: astralTrinket) == [
            ResourceAmount(.herbs, 16),
            ResourceAmount(.crystal, 8),
        ])
        #expect(ItemSalvage.yields(for: basicArmor) == [
            ResourceAmount(.hide, 8),
            ResourceAmount(.stone, 4),
        ])
    }

    @Test @MainActor func salvageRemovesItemGrantsMaterialsAndPersists() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let item = try SaveTestSupport.makeGeneratedItem(
            baseID: "longsword",
            rarity: .basic,
            id: "salvage-sword"
        )
        var save = store.currentSave
        save.inventory.items = [item]
        save.homestead.resources = [:]
        try store.performBatchMutation { $0 = save }

        var result: ItemSalvageResult = .itemNotFound
        try store.performBatchMutation { save in
            result = ItemSalvageApplier.salvage(itemID: item.id, save: &save)
        }

        #expect(result == .success(yields: [
            ResourceAmount(.iron, 8),
            ResourceAmount(.wood, 4),
        ]))
        #expect(store.inventory.items.isEmpty)
        #expect(store.homestead.resources[.iron] == 8)
        #expect(store.homestead.resources[.wood] == 4)

        let reloaded = try PlayerSaveStore(
            storeURL: context.storeURL(),
            disableCloudSync: true
        )
        #expect(reloaded.inventory.items.isEmpty)
        #expect(reloaded.homestead.resources[.iron] == 8)
        #expect(reloaded.homestead.resources[.wood] == 4)
    }

    @Test func salvageUnequipsItemFromLoadouts() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now)
        let item = try SaveTestSupport.makeGeneratedItem(
            baseID: "longsword",
            rarity: .basic,
            id: "equipped-sword"
        )
        save.inventory.items = [item]
        save.roster.equipmentLoadouts["knight"] = EquipmentLoadout(
            itemIDsBySlot: [.weapon: item.id]
        )

        let result = ItemSalvageApplier.salvage(itemID: item.id, save: &save)

        guard case .success = result else {
            Issue.record("Expected successful salvage")
            return
        }
        #expect(save.inventory.items.isEmpty)
        #expect(save.roster.equipmentLoadouts["knight"]?.itemID(for: .weapon) == nil)
        #expect(save.homestead.resources[.iron] == 8)
        #expect(save.homestead.resources[.wood] == 4)
    }

    @Test func unknownItemLeavesSaveUnchanged() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now)
        let item = try SaveTestSupport.makeGeneratedItem(baseID: "longsword", rarity: .basic, id: "keep-me")
        save.inventory.items = [item]
        save.homestead.resources = [.iron: 3]
        let before = save

        let result = ItemSalvageApplier.salvage(itemID: "missing", save: &save)

        #expect(result == .itemNotFound)
        #expect(save == before)
    }

    @Test func trinketsCannotBeSalvaged() throws {
        let trinket = try #require(GameContent.trinketItems.first)
        var save = SaveTestSupport.makeSave(modifiedAt: .now)
        save.inventory.items = [trinket]
        let before = save

        let result = ItemSalvageApplier.salvage(itemID: trinket.id, save: &save)

        #expect(result == .ineligible)
        #expect(save == before)
    }

    @Test func uniquesCannotBeSalvaged() throws {
        let unique = try #require(GameContent.unique(matching: "bloodfire_signet"))
        var save = SaveTestSupport.makeSave()
        save.inventory.items = [unique]
        let before = save

        let result = ItemSalvageApplier.salvage(itemID: unique.id, save: &save)

        #expect(result == .ineligible)
        #expect(save == before)
    }

    @Test func salvageGrantsFullYieldBeyondLegacyMaterialCap() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now)
        let item = try SaveTestSupport.makeGeneratedItem(baseID: "longsword", rarity: .basic, id: "cap-sword")
        save.inventory.items = [item]
        save.homestead.resources = [
            .iron: 997,
            .wood: 999,
        ]

        let result = ItemSalvageApplier.salvage(itemID: item.id, save: &save)

        guard case let .success(yields) = result else {
            Issue.record("Expected successful salvage")
            return
        }
        #expect(yields == [ResourceAmount(.iron, 8), ResourceAmount(.wood, 4)])
        #expect(save.inventory.items.isEmpty)
        #expect(save.homestead.resources[.iron] == 1005)
        #expect(save.homestead.resources[.wood] == 1003)
    }
}
