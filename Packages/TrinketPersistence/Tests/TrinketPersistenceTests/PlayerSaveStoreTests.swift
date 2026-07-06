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

    func testPlayerSavePersistsJourneyRosterInventoryAndHomestead() throws {
        let fileStore = makeFileStore()
        let firstStore = PlayerSaveStore(fileStore: fileStore, persistDebounceNanoseconds: 0)
        firstStore.grantGold(42)
        firstStore.grantExperience(20, to: GameContent.heroes[0])
        firstStore.grantHomestead([ResourceAmount(.wood, 14), ResourceAmount(.crystal, 2)])
        let template = try XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic"))
        firstStore.appendInventoryItem(template.rewardInstance(for: "chapter-1-stage-1"))
        firstStore.advanceJourneyToStage("chapter-1-stage-2")

        let secondStore = PlayerSaveStore(fileStore: fileStore, persistDebounceNanoseconds: 0)

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
        let fileStore = makeFileStore()
        var save = PlayerSave.testSeed
        save.roster.equipmentLoadouts["knight"] = SavedEquipmentLoadout(
            EquipmentLoadout(itemIDsBySlot: [.weapon: "missing-item"])
        )
        try fileStore.save(save)

        let store = PlayerSaveStore(fileStore: fileStore, persistDebounceNanoseconds: 0)
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

    func testPersistFailureUpdatesMemoryAndQueuesPendingFlush() throws {
        let fileStore = makeFileStore()
        let store = PlayerSaveStore(
            fileStore: fileStore,
            immediatePersistRetryCount: 1,
            immediatePersistRetryDelayNanoseconds: 0,
            persistDebounceNanoseconds: 0
        )
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

        XCTAssertEqual(store.roster.gold, 15)
        XCTAssertTrue(store.hasPendingPersist)
        XCTAssertEqual(store.lastPersistenceError, .writeFailed)

        let reloadedBeforeFlush = PlayerSaveStore(fileStore: fileStore, persistDebounceNanoseconds: 0)
        XCTAssertEqual(reloadedBeforeFlush.roster.gold, 10)

        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: directoryURL.path
        )
        store.flushPendingPersistIfNeeded()

        XCTAssertFalse(store.hasPendingPersist)
        XCTAssertNil(store.lastPersistenceError)

        let reloadedAfterFlush = PlayerSaveStore(fileStore: fileStore, persistDebounceNanoseconds: 0)
        XCTAssertEqual(reloadedAfterFlush.roster.gold, 15)
    }

    func testPerformBatchMutationAppliesOptimisticallyWhenPersistFails() throws {
        let fileStore = makeFileStore()
        let store = PlayerSaveStore(
            fileStore: fileStore,
            immediatePersistRetryCount: 1,
            immediatePersistRetryDelayNanoseconds: 0,
            persistDebounceNanoseconds: 0
        )

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

        var journey = store.journey
        journey.completedStageIDs.insert("chapter-1-stage-1")
        journey.activeStageID = "chapter-1-stage-2"

        try store.performBatchMutation { save in
            save.journey = journey
            save.roster.gold = 42
        }

        XCTAssertEqual(store.journey.activeStageID, "chapter-1-stage-2")
        XCTAssertEqual(store.roster.gold, 42)
        XCTAssertTrue(store.hasPendingPersist)
    }

    func testSanitizerUsesCatalogOrderForLastCompletedStage() {
        var journey = JourneyProgressState.initial
        journey.completedStageIDs = ["chapter-1-stage-9", "chapter-1-stage-10"]
        journey.lastCompletedStageID = "chapter-1-stage-9"

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        XCTAssertEqual(sanitized.lastCompletedStageID, "chapter-1-stage-10")
    }

    func testApplyRemoteSavePreservesModifiedAt() throws {
        let fileStore = makeFileStore()
        let store = makeStore()
        let remoteTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        var remoteSave = PlayerSave.fresh
        remoteSave.modifiedAt = remoteTimestamp
        remoteSave.roster.gold = 99

        try store.applyRemoteSave(remoteSave)

        XCTAssertEqual(store.currentSave.modifiedAt, remoteTimestamp)
        XCTAssertEqual(store.roster.gold, 99)
        XCTAssertTrue(store.loadedFromDisk)
    }

    func testLocalMutationUpdatesModifiedAt() throws {
        let fileStore = makeFileStore()
        let store = makeStore()
        let remoteTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        var remoteSave = PlayerSave.fresh
        remoteSave.modifiedAt = remoteTimestamp
        try store.applyRemoteSave(remoteSave)

        let beforeLocalEdit = store.currentSave.modifiedAt
        store.grantGold(1)

        XCTAssertGreaterThan(store.currentSave.modifiedAt, beforeLocalEdit)
    }

    func testLoadedFromDiskWhenSaveFileExists() throws {
        let fileStore = makeFileStore()
        var save = PlayerSave.fresh
        save.roster.gold = 7
        try fileStore.save(save)

        let store = PlayerSaveStore(fileStore: fileStore, persistDebounceNanoseconds: 0)

        XCTAssertTrue(store.loadedFromDisk)
        XCTAssertEqual(store.roster.gold, 7)
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
                XCTFail("Expected invalidSave, got \(error)")
            }
        }
    }

    func testCorruptSaveFallsBackToFreshStartAndSetsFlag() throws {
        let fileStore = makeFileStore()
        try "corrupt".write(to: fileStore.saveFileURL, atomically: true, encoding: .utf8)
        try "also corrupt".write(to: fileStore.backupFileURL, atomically: true, encoding: .utf8)

        let store = PlayerSaveStore(fileStore: fileStore, persistDebounceNanoseconds: 0)

        XCTAssertTrue(store.hadCorruptSaveOnLoad)
        XCTAssertEqual(store.roster, .freshStart)
        XCTAssertEqual(store.journey, .initial)
        XCTAssertEqual(store.inventory, .freshStart)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileStore.saveFileURL.path))
    }

    private func makeFileStore() -> PlayerSaveFileStore {
        SaveTestSupport.makeFileStore(directoryURL: directoryURL)
    }

    private func makeStore() -> PlayerSaveStore {
        PlayerSaveStore(
            fileStore: makeFileStore(),
            persistDebounceNanoseconds: 0
        )
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
