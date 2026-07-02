import XCTest
@testable import Trinket

@MainActor
final class PlayerInventoryStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "PlayerInventoryStoreTests")
    }

    override func tearDown() async throws {
        SaveTestSupport.removeTempDirectory(directoryURL)
        try await super.tearDown()
    }

    func testItemsForSlotFiltersInventory() throws {
        let weaponBase = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.slot == .weapon })
        let armorBase = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.slot == .armor })
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
        let saveStore = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        saveStore.inventory = PlayerInventoryState(items: [weapon, armor])
        let inventoryStore = PlayerInventoryStore(saveStore: saveStore)

        XCTAssertEqual(inventoryStore.items(for: .weapon).map(\.id), ["weapon-item"])
        XCTAssertEqual(inventoryStore.items(for: .armor).map(\.id), ["armor-item"])
    }

    func testItemsForSlotReflectsPersistedInventory() throws {
        let weaponBase = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.slot == .weapon })
        let weapon = InventoryItem(
            id: "persisted-weapon",
            templateID: "weapon-template",
            baseType: weaponBase,
            rarity: .basic,
            displayName: "Weapon",
            affixes: []
        )
        let saveStore = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        saveStore.inventory = PlayerInventoryState(items: [weapon])

        let reloadedStore = PlayerInventoryStore(saveStore: SaveTestSupport.makeSaveStore(directoryURL: directoryURL))

        XCTAssertEqual(reloadedStore.items(for: .weapon).map(\.id), ["persisted-weapon"])
    }

    func testAddRewardItemWriteThroughToSaveStore() throws {
        let saveStore = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        let inventoryStore = PlayerInventoryStore(saveStore: saveStore)
        let template = try XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic"))
        let stage = GameContent.chapters[0].stages[0]

        inventoryStore.addRewardItem(from: template, for: stage)

        let reloaded = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        XCTAssertNotNil(reloaded.inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
    }
}
