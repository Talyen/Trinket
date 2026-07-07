import SwiftData
import XCTest
import TrinketContent
import TrinketCore
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

    func testPlayerSavePersistsJourneyRosterInventoryAndHomestead() throws {
        let storeURL = makeStoreURL()
        let firstStore = PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        firstStore.grantGold(42)
        firstStore.grantExperience(20, to: GameContent.heroes[0])
        firstStore.grantHomestead([ResourceAmount(.wood, 14), ResourceAmount(.crystal, 2)])
        let template = try XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic"))
        firstStore.appendInventoryItem(template.rewardInstance(for: "chapter-1-stage-1"))
        firstStore.advanceJourneyToStage("chapter-1-stage-2")

        let secondStore = PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        XCTAssertEqual(secondStore.roster.gold, 42)
        XCTAssertEqual(secondStore.roster.progression(for: GameContent.heroes[0]).currentXP, 20)
        XCTAssertEqual(secondStore.homestead.resources[.wood], 14)
        XCTAssertEqual(secondStore.homestead.resources[.crystal], 2)
        XCTAssertNotNil(secondStore.inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        XCTAssertEqual(secondStore.journey.activeStageID, "chapter-1-stage-2")
    }

    func testSwiftDataGraphStoresIndependentRecords() throws {
        let storeURL = makeStoreURL()
        let store = PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        store.grantGold(5)
        store.advanceJourneyToStage("chapter-1-stage-2")
        store.grantHomestead([ResourceAmount(.wood, 3)])
        let template = try XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic"))
        store.appendInventoryItem(template.rewardInstance(for: "chapter-1-stage-1"))

        let container = try ModelContainer(
            for: PlayerSaveGraph.schema,
            configurations: ModelConfiguration(schema: PlayerSaveGraph.schema, url: storeURL, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)

        XCTAssertEqual(try context.fetch(FetchDescriptor<RosterModel>()).first?.gold, 5)
        XCTAssertTrue(try context.fetch(FetchDescriptor<JourneyStageProgressModel>()).contains {
            $0.stageID == "chapter-1-stage-1" && $0.isCompleted
        })
        XCTAssertTrue(try context.fetch(FetchDescriptor<InventoryItemModel>()).contains {
            $0.id == "chapter-1-stage-1-shortsword-basic"
        })
        XCTAssertTrue(try context.fetch(FetchDescriptor<HomesteadResourceBalanceModel>()).contains {
            $0.resourceID == HomesteadResource.wood.rawValue && $0.quantity == 3
        })
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
        XCTAssertEqual(store.currentSave.sessionGeneration, 1)
    }

    func testApplyTestSeedMatchesDeterministicUITestBaseline() throws {
        let store = makeStore()
        try store.applyTestSeed()

        XCTAssertEqual(store.roster, .testSeed)
        XCTAssertEqual(store.inventory, .testSeed)
        XCTAssertEqual(store.homestead, .testSeed)
    }

    func testEquipmentLoadoutDropsMissingInventoryItemsOnLoad() throws {
        let storeURL = makeStoreURL()
        let firstStore = PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        var save = PlayerSave.testSeed
        save.roster.equipmentLoadouts["knight"] = SavedEquipmentLoadout(
            EquipmentLoadout(itemIDsBySlot: [.weapon: "missing-item"])
        )
        try firstStore.performBatchMutation { $0 = save }

        let store = PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })

        XCTAssertNil(store.roster.equipmentLoadout(for: knight).itemID(for: .weapon))
    }

    func testRosterCacheReturnsConsistentHydratedState() throws {
        let store = makeStore()
        let template = try XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic"))
        let item = template.rewardInstance(for: "chapter-1-stage-1")
        store.appendInventoryItem(item)
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })

        var roster = store.roster
        var loadout = roster.equipmentLoadout(for: knight)
        loadout.equip(item)
        roster.setEquipmentLoadout(loadout, for: knight)
        store.roster = roster

        let firstRead = store.roster
        let secondRead = store.roster
        XCTAssertEqual(firstRead, secondRead)
        XCTAssertEqual(
            firstRead.equipmentLoadout(for: knight).itemID(for: .weapon),
            "chapter-1-stage-1-shortsword-basic"
        )
    }

    func testLocalMutationUpdatesModifiedAt() {
        let store = makeStore()
        let beforeLocalEdit = store.currentSave.modifiedAt
        store.grantGold(1)

        XCTAssertGreaterThan(store.currentSave.modifiedAt, beforeLocalEdit)
    }

    func testSanitizerUsesCatalogOrderForLastCompletedStage() {
        var journey = JourneyProgressState.initial
        journey.completedStageIDs = ["chapter-1-stage-9", "chapter-1-stage-10"]
        journey.lastCompletedStageID = "chapter-1-stage-9"

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        XCTAssertEqual(sanitized.lastCompletedStageID, "chapter-1-stage-10")
    }

    func testValidateRejectsNegativeProgressionXP() {
        var save = PlayerSave.fresh
        save.roster.progressions["knight"] = CombatantProgression(level: 1, currentXP: -1, requiredXP: 100)

        XCTAssertThrowsError(try PlayerSaveSanitizer.validate(save)) { error in
            guard case let PlayerSavePersistenceError.invalidSave(message) = error else {
                return XCTFail("Expected invalidSave, got \(error)")
            }
            XCTAssertTrue(message.contains("current XP"))
        }
    }

    func testValidateRejectsInvalidSchemaVersion() {
        var save = PlayerSave.fresh
        save.schemaVersion = 0

        XCTAssertThrowsError(try PlayerSaveSanitizer.validate(save)) { error in
            guard case PlayerSavePersistenceError.invalidSave = error else {
                return XCTFail("Expected invalidSave, got \(error)")
            }
        }
    }

    func testPerformBatchMutationPreservesStateWhenValidationFails() throws {
        let store = makeStore()
        store.grantGold(25)
        let snapshot = store.currentSave

        XCTAssertThrowsError(
            try store.performBatchMutation { save in
                save.schemaVersion = 0
            }
        )

        XCTAssertEqual(store.currentSave, snapshot)
        XCTAssertEqual(store.roster.gold, 25)
        XCTAssertNil(store.lastPersistenceError)
    }

    #if DEBUG
    func testPerformBatchMutationRollsBackInMemoryStateWhenSaveFails() throws {
        let store = makeStore()
        store.grantGold(10)
        store.forcesNextSaveFailure = true

        XCTAssertThrowsError(
            try store.performBatchMutation { save in
                save.roster.gold += 50
            }
        ) { error in
            guard case PlayerSavePersistenceError.writeFailed = error else {
                return XCTFail("Expected writeFailed, got \(error)")
            }
        }

        XCTAssertEqual(store.roster.gold, 10)
        XCTAssertEqual(store.lastPersistenceError, .writeFailed)
    }
    #endif

    private func makeStoreURL() -> URL {
        SaveTestSupport.makeStoreURL(directoryURL: directoryURL)
    }

    private func makeStore() -> PlayerSaveStore {
        PlayerSaveStore(storeURL: makeStoreURL(), disableCloudSync: true)
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
