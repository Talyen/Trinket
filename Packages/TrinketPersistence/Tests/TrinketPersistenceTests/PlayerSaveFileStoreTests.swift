import XCTest
import TrinketContent
@testable import TrinketPersistence

@MainActor
final class PlayerSaveFileStoreTests: XCTestCase {
    private var directoryURL: URL!
    private let legacyJourneyKey = PlayerSaveFileStore.legacyJourneyKey

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlayerSaveFileStoreTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        UserDefaults.standard.removeObject(forKey: legacyJourneyKey)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: legacyJourneyKey)
        try? FileManager.default.removeItem(at: directoryURL)
        try await super.tearDown()
    }

    func testSaveAndLoadRoundTripsSave() throws {
        let fileStore = makeFileStore()
        var save = PlayerSave.fresh
        save.roster.gold = 77

        try fileStore.save(save)
        let loaded = fileStore.load()

        XCTAssertEqual(loaded?.roster.gold, 77)
        XCTAssertEqual(loaded?.schemaVersion, PlayerSave.currentSchemaVersion)
    }

    func testLoadRecoversFromBackupWhenPrimaryCorrupt() throws {
        let fileStore = makeFileStore()
        var save = PlayerSave.fresh
        save.roster.gold = 55
        try fileStore.save(save)
        try fileStore.save(save)

        try "not valid json".write(to: fileStore.saveFileURL, atomically: true, encoding: .utf8)

        let loaded = try XCTUnwrap(fileStore.load())

        XCTAssertEqual(loaded.roster.gold, 55)
    }

    func testLoadQuarantinesUnsupportedNewerSchemaSave() throws {
        let fileStore = makeFileStore()
        let newerSchemaJSON = """
        {
          "schemaVersion": \(PlayerSave.currentSchemaVersion + 1),
          "modifiedAt": "2026-01-01T00:00:00.000Z",
          "sessionGeneration": 0,
          "journey": {
            "activeChapterID": "chapter-1",
            "activeStageID": "chapter-1-stage-1",
            "completedStageIDs": [],
            "claimedRewardStageIDs": [],
            "lastCompletedStageID": null
          },
          "roster": {
            "activeHeroID": "knight",
            "activePetID": "bear",
            "abilityLoadouts": {},
            "progressions": {},
            "equipmentLoadouts": {},
            "gold": 99
          },
          "inventory": { "items": [] },
          "homestead": { "resources": {}, "nodeTiers": {} }
        }
        """
        try newerSchemaJSON.write(to: fileStore.saveFileURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(fileStore.loadOutcome(), .unsupportedNewerSchema)
        XCTAssertNil(fileStore.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileStore.saveFileURL.path))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: fileStore.saveFileURL.appendingPathExtension("newer-schema").path)
        )

        let store = PlayerSaveStore(fileStore: fileStore, persistDebounceNanoseconds: 0)
        XCTAssertTrue(store.hadUnsupportedNewerSaveOnLoad)
        XCTAssertEqual(store.roster.gold, PlayerSave.fresh.roster.gold)
    }

    func testLoadReturnsNilWhenBothFilesCorrupt() throws {
        let fileStore = makeFileStore()
        var save = PlayerSave.fresh
        try fileStore.save(save)

        try "corrupt".write(to: fileStore.saveFileURL, atomically: true, encoding: .utf8)
        try "also corrupt".write(to: fileStore.backupFileURL, atomically: true, encoding: .utf8)

        XCTAssertNil(fileStore.load())
        XCTAssertEqual(fileStore.loadOutcome(), .corrupt)
    }

    func testDeleteSaveRemovesAllSaveFiles() throws {
        let fileStore = makeFileStore()
        try fileStore.save(PlayerSave.fresh)

        fileStore.deleteSave()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileStore.saveFileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileStore.backupFileURL.path))
        XCTAssertNil(fileStore.load())
    }

    func testMigrateLegacyUserDefaultsPreservesKeyWhenSaveFails() throws {
        let fileStore = makeFileStore()
        var journey = JourneyProgressState.initial
        journey.completedStageIDs.insert("chapter-1-stage-1")
        journey.activeStageID = "chapter-1-stage-2"
        let data = try PlayerSaveCoding.makeEncoder().encode(journey)
        UserDefaults.standard.set(data, forKey: legacyJourneyKey)

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

        XCTAssertNil(fileStore.load())
        XCTAssertNotNil(UserDefaults.standard.data(forKey: legacyJourneyKey))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileStore.saveFileURL.path))
    }

    func testMigrateLegacyUserDefaultsJourney() throws {
        let fileStore = makeFileStore()
        var journey = JourneyProgressState.initial
        journey.completedStageIDs.insert("chapter-1-stage-1")
        journey.activeStageID = "chapter-1-stage-2"
        journey.lastCompletedStageID = "chapter-1-stage-1"
        let data = try PlayerSaveCoding.makeEncoder().encode(journey)
        UserDefaults.standard.set(data, forKey: legacyJourneyKey)

        let loaded = try XCTUnwrap(fileStore.load())

        XCTAssertEqual(loaded.journey.activeStageID, "chapter-1-stage-2")
        XCTAssertNil(UserDefaults.standard.data(forKey: legacyJourneyKey))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileStore.saveFileURL.path))
    }

    private func makeFileStore() -> PlayerSaveFileStore {
        PlayerSaveFileStore(directoryURL: directoryURL)
    }
}
