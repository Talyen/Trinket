import XCTest
import TrinketCore
import TrinketContent
@testable import TrinketPersistence

@MainActor
final class PlayerSaveStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "PlayerSaveStoreTests")
    }

    override func tearDown() async throws {
        SaveTestSupport.removeTempDirectory(directoryURL)
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
        let template = try XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic"))
        firstStore.appendInventoryItem(template.rewardInstance(for: "chapter-1-stage-1"))
        firstStore.advanceJourneyToStage("chapter-1-stage-2")

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
        let template = try XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic"))
        store.appendInventoryItem(template.rewardInstance(for: "chapter-1-stage-1"))
        store.advanceJourneyToStage("chapter-1-stage-2")

        try store.resetGameplayProgress()

        XCTAssertEqual(store.roster, .freshStart)
        XCTAssertEqual(store.inventory, .freshStart)
        XCTAssertEqual(store.homestead, .freshStart)
        XCTAssertEqual(store.journey, .initial)
    }

    func testApplyTestSeedMatchesDeterministicUITestBaseline() throws {
        let store = makeStore()
        try store.applyTestSeed()

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
        try fileStore.save(save)

        let store = PlayerSaveStore(fileStore: fileStore)
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })

        XCTAssertNil(store.roster.equipmentLoadout(for: knight).itemID(for: .weapon))
    }

    func testPersistFailureLeavesSaveUnchanged() throws {
        let fileStore = makeFileStore()
        let store = makeStore()
        store.grantGold(10)

        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o555))],
            ofItemAtPath: directoryURL.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o755))],
                ofItemAtPath: directoryURL.path
            )
        }

        store.grantGold(5)

        XCTAssertEqual(store.roster.gold, 10)
        XCTAssertEqual(store.lastPersistenceError, .writeFailed)

        let reloaded = PlayerSaveStore(fileStore: fileStore)
        XCTAssertEqual(reloaded.roster.gold, 10)
    }

    func testSanitizerUsesCatalogOrderForLastCompletedStage() {
        var journey = JourneyProgressState.initial
        journey.completedStageIDs = ["chapter-1-stage-9", "chapter-1-stage-10"]
        journey.lastCompletedStageID = "chapter-1-stage-9"

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        XCTAssertEqual(sanitized.lastCompletedStageID, "chapter-1-stage-10")
    }

    private func makeFileStore() -> PlayerSaveFileStore {
        SaveTestSupport.makeFileStore(directoryURL: directoryURL)
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

    func appendInventoryItem(_ item: InventoryItem) {
        var updated = inventory
        updated.items.append(item)
        inventory = updated
    }

    func advanceJourneyToStage(_ stageID: String) {
        var updated = journey
        updated.completedStageIDs.insert("chapter-1-stage-1")
        updated.activeStageID = stageID
        updated.lastCompletedStageID = "chapter-1-stage-1"
        journey = updated
    }

    func grantHomestead(_ rewards: [ResourceAmount]) {
        var updated = homestead
        updated.grant(rewards)
        homestead = updated
    }
}
