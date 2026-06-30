import XCTest
@testable import Trinket

@MainActor
final class PlayerInventoryStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlayerInventoryStoreTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directoryURL)
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
        let saveStore = PlayerSaveStore(fileStore: makeFileStore())
        saveStore.inventory = PlayerInventoryState(items: [weapon, armor])
        let inventoryStore = PlayerInventoryStore(saveStore: saveStore)

        XCTAssertEqual(inventoryStore.items(for: .weapon).map(\.id), ["weapon-item"])
        XCTAssertEqual(inventoryStore.items(for: .armor).map(\.id), ["armor-item"])
    }

    func testAddRewardItemWriteThroughToSaveStore() throws {
        let saveStore = PlayerSaveStore(fileStore: makeFileStore())
        let inventoryStore = PlayerInventoryStore(saveStore: saveStore)
        let template = try XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic"))
        let stage = GameContent.chapters[0].stages[0]

        inventoryStore.addRewardItem(from: template, for: stage)

        let reloaded = PlayerSaveStore(fileStore: makeFileStore())
        XCTAssertNotNil(reloaded.inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
    }

    private func makeFileStore() -> PlayerSaveFileStore {
        PlayerSaveFileStore(directoryURL: directoryURL)
    }
}
