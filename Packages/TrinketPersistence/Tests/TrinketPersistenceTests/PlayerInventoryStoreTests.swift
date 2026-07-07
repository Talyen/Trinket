import Testing
import TrinketContent
@testable import TrinketPersistence

@Suite @MainActor
final class PlayerInventoryStoreTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func itemsForSlotFiltersInventory() throws {
        let weaponBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .weapon })
        let armorBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .armor })
        let weapon = InventoryItem(
            id: "weapon-item",
            templateID: "weapon-template",
            baseType: weaponBase,
            rarity: .basic,
            displayName: "Weapon",
            affixes: []
        )
        let armor = InventoryItem(
            id: "armor-item",
            templateID: "armor-template",
            baseType: armorBase,
            rarity: .basic,
            displayName: "Armor",
            affixes: []
        )
        let saveStore = context.makeSaveStore()
        saveStore.inventory = PlayerInventoryState(items: [weapon, armor])
        let inventoryStore = PlayerInventoryStore(saveStore: saveStore)

        #expect(inventoryStore.current.items(for: .weapon).map(\.id) == ["weapon-item"])
        #expect(inventoryStore.current.items(for: .armor).map(\.id) == ["armor-item"])
    }

    @Test func itemsForSlotReflectsPersistedInventory() throws {
        let weaponBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .weapon })
        let weapon = InventoryItem(
            id: "persisted-weapon",
            templateID: "weapon-template",
            baseType: weaponBase,
            rarity: .basic,
            displayName: "Weapon",
            affixes: []
        )
        let saveStore = context.makeSaveStore()
        saveStore.inventory = PlayerInventoryState(items: [weapon])

        let reloadedStore = PlayerInventoryStore(saveStore: context.makeSaveStore())

        #expect(reloadedStore.current.items(for: .weapon).map(\.id) == ["persisted-weapon"])
    }

    @Test func addRewardItemWriteThroughToSaveStore() throws {
        let saveStore = context.makeSaveStore()
        let inventoryStore = PlayerInventoryStore(saveStore: saveStore)
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        let stage = GameContent.chapters[0].stages[0]

        inventoryStore.addRewardItem(from: template, for: stage)

        let reloaded = context.makeSaveStore()
        _ = try #require(reloaded.inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
    }
}
