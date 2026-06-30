import XCTest
@testable import Trinket

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

    func testSaveAndLoadRoundTripsSave() {
        let fileStore = makeFileStore()
        var save = PlayerSave.fresh
        save.roster.gold = 77

        fileStore.save(save)
        let loaded = fileStore.load()

        XCTAssertEqual(loaded?.roster.gold, 77)
        XCTAssertEqual(loaded?.schemaVersion, PlayerSave.currentSchemaVersion)
    }

    func testLoadRecoversFromBackupWhenPrimaryCorrupt() throws {
        let fileStore = makeFileStore()
        var save = PlayerSave.fresh
        save.roster.gold = 55
        fileStore.save(save)
        fileStore.save(save)

        try "not valid json".write(to: fileStore.saveFileURL, atomically: true, encoding: .utf8)

        let loaded = try XCTUnwrap(fileStore.load())

        XCTAssertEqual(loaded.roster.gold, 55)
    }

    func testLoadReturnsNilWhenBothFilesCorrupt() throws {
        let fileStore = makeFileStore()
        var save = PlayerSave.fresh
        fileStore.save(save)

        try "corrupt".write(to: fileStore.saveFileURL, atomically: true, encoding: .utf8)
        try "also corrupt".write(to: fileStore.backupFileURL, atomically: true, encoding: .utf8)

        XCTAssertNil(fileStore.load())
    }

    func testDeleteSaveRemovesAllSaveFiles() {
        let fileStore = makeFileStore()
        fileStore.save(PlayerSave.fresh)

        fileStore.deleteSave()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileStore.saveFileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileStore.backupFileURL.path))
        XCTAssertNil(fileStore.load())
    }

    func testMigrateLegacyUserDefaultsJourney() throws {
        let fileStore = makeFileStore()
        var journey = JourneyProgressState.initial
        journey.complete(GameContent.chapters[0].stages[0], in: GameContent.chapters)
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
