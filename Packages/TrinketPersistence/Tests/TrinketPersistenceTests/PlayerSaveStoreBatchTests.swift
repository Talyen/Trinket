import XCTest
@testable import TrinketPersistence

@MainActor
final class PlayerSaveStoreBatchTests: XCTestCase {
    private var directoryURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "PlayerSaveStoreBatchTests")
    }

    override func tearDown() async throws {
        SaveTestSupport.removeTempDirectory(directoryURL)
        try await super.tearDown()
    }

    func testPerformBatchMutationPersistsOnce() throws {
        let fileStore = SaveTestSupport.makeFileStore(directoryURL: directoryURL)
        let store = PlayerSaveStore(
            fileStore: fileStore,
            persistDebounceNanoseconds: 0
        )
        var persistCount = 0
        store.onLocalSave = { _ in persistCount += 1 }

        try store.performBatchMutation { save in
            save.roster.gold = 50
            save.journey.completedStageIDs.insert("chapter-1-stage-1")
        }

        XCTAssertEqual(persistCount, 1)
        XCTAssertEqual(store.roster.gold, 50)
        XCTAssertTrue(store.journey.completedStageIDs.contains("chapter-1-stage-1"))
    }

    func testPerformBatchMutationFlushesDebouncedPersistImmediately() throws {
        let fileStore = SaveTestSupport.makeFileStore(directoryURL: directoryURL)
        let store = PlayerSaveStore(
            fileStore: fileStore,
            persistDebounceNanoseconds: 1_000_000_000
        )
        store.grantGoldForTests(4)

        try store.performBatchMutation { save in
            save.roster.gold = 12
        }

        XCTAssertFalse(store.hasPendingPersist)
        let reloaded = PlayerSaveStore(
            fileStore: fileStore,
            persistDebounceNanoseconds: 0
        )
        XCTAssertEqual(reloaded.roster.gold, 12)
    }

    func testRapidMutationsCoalesceBeforeFlush() throws {
        let fileStore = SaveTestSupport.makeFileStore(directoryURL: directoryURL)
        let store = PlayerSaveStore(
            fileStore: fileStore,
            persistDebounceNanoseconds: 1_000_000_000
        )

        for _ in 0 ..< 10 {
            store.grantGoldForTests(1)
        }

        XCTAssertTrue(store.hasPendingPersist)
        let reloadedBeforeFlush = PlayerSaveStore(
            fileStore: fileStore,
            persistDebounceNanoseconds: 0
        )
        XCTAssertEqual(reloadedBeforeFlush.roster.gold, 0)

        store.flushPendingPersistIfNeeded()

        XCTAssertFalse(store.hasPendingPersist)
        let reloadedAfterFlush = PlayerSaveStore(
            fileStore: fileStore,
            persistDebounceNanoseconds: 0
        )
        XCTAssertEqual(reloadedAfterFlush.roster.gold, 10)
    }

    func testDebouncedMutationNotifiesLocalSaveAfterFlush() throws {
        let fileStore = SaveTestSupport.makeFileStore(directoryURL: directoryURL)
        let store = PlayerSaveStore(
            fileStore: fileStore,
            persistDebounceNanoseconds: 0
        )
        var persistCount = 0
        store.onLocalSave = { _ in persistCount += 1 }

        store.grantGoldForTests(3)

        XCTAssertEqual(persistCount, 1)
        XCTAssertEqual(store.roster.gold, 3)
    }
}
