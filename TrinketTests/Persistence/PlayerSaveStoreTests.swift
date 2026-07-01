import XCTest
@testable import Trinket

@MainActor
final class PlayerSaveStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlayerSaveStoreTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directoryURL)
        try await super.tearDown()
    }

    func testFreshSaveStartsWithKnightAndBearStarters() {
        let store = makeStore()

        XCTAssertEqual(store.roster.unlockedHeroIDs, [PlayerRosterState.starterHeroID])
        XCTAssertEqual(store.roster.unlockedPetIDs, [PlayerRosterState.starterPetID])
        XCTAssertEqual(store.roster.activeHeroID, PlayerRosterState.starterHeroID)
        XCTAssertEqual(store.roster.activePetID, PlayerRosterState.starterPetID)
        XCTAssertEqual(store.inventory, .freshStart)
        XCTAssertEqual(store.homestead, .freshStart)
        XCTAssertEqual(store.journey, .initial)
    }

    func testPlayerSavePersistsJourneyRosterInventoryAndHomestead() throws {
        let fileStore = makeFileStore()
        let firstStore = PlayerSaveStore(fileStore: fileStore)
        firstStore.grantGold(42)
        firstStore.grantExperience(20, to: GameContent.heroes[0])
        firstStore.grantHomestead([ResourceAmount(.wood, 14), ResourceAmount(.crystal, 2)])
        try firstStore.addRewardItem(
            from: XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic")),
            for: GameContent.chapters[0].stages[0]
        )
        firstStore.complete(GameContent.chapters[0].stages[0], in: GameContent.chapters)

        let secondStore = PlayerSaveStore(fileStore: fileStore)

        XCTAssertEqual(secondStore.roster.gold, 42)
        XCTAssertEqual(secondStore.roster.progression(for: GameContent.heroes[0]).currentXP, 20)
        XCTAssertEqual(secondStore.homestead.resources[.wood], 14)
        XCTAssertEqual(secondStore.homestead.resources[.crystal], 2)
        XCTAssertNotNil(secondStore.inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        XCTAssertEqual(secondStore.journey.activeStageID, "chapter-1-stage-2")
    }

    func testResetGameplayProgressRestoresFreshStart() throws {
        let store = makeStore()
        store.grantGold(99)
        try store.addRewardItem(
            from: XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic")),
            for: GameContent.chapters[0].stages[0]
        )
        store.complete(GameContent.chapters[0].stages[0], in: GameContent.chapters)

        store.resetGameplayProgress()

        XCTAssertEqual(store.roster, .freshStart)
        XCTAssertEqual(store.inventory, .freshStart)
        XCTAssertEqual(store.homestead, .freshStart)
        XCTAssertEqual(store.journey, .initial)
    }

    func testApplyTestSeedMatchesDeterministicUITestBaseline() {
        let store = makeStore()
        store.applyTestSeed()

        XCTAssertEqual(store.roster, .testSeed)
        XCTAssertEqual(store.inventory, .testSeed)
        XCTAssertEqual(store.homestead, .testSeed)
    }

    func testEquipmentLoadoutDropsMissingInventoryItemsOnLoad() throws {
        let fileStore = makeFileStore()
        var save = PlayerSave.testSeed
        save.roster.equipmentLoadouts["knight"] = SavedEquipmentLoadout(
            EquipmentLoadout(itemIDsBySlot: [.weapon: "missing-item"])
        )
        fileStore.save(save)

        let store = PlayerSaveStore(fileStore: fileStore)
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })

        XCTAssertNil(store.roster.equipmentLoadout(for: knight).itemID(for: .weapon))
    }

    private func makeFileStore() -> PlayerSaveFileStore {
        PlayerSaveFileStore(directoryURL: directoryURL)
    }

    private func makeStore() -> PlayerSaveStore {
        PlayerSaveStore(fileStore: makeFileStore())
    }
}

private extension PlayerSaveStore {
    func grantExperience(_ amount: Int, to combatant: Combatant) {
        var updated = roster
        updated.grantExperience(amount, to: combatant)
        roster = updated
    }

    func grantGold(_ amount: Int) {
        var updated = roster
        updated.grantGold(amount)
        roster = updated
    }

    func addRewardItem(from template: InventoryItem, for stage: Stage) {
        var updated = inventory
        updated.addRewardItem(from: template, for: stage)
        inventory = updated
    }

    func complete(_ stage: Stage, in chapters: [Chapter]) {
        var updated = journey
        updated.complete(stage, in: chapters)
        journey = updated
    }

    func grantHomestead(_ rewards: [ResourceAmount]) {
        var updated = homestead
        updated.grant(rewards)
        homestead = updated
    }
}
