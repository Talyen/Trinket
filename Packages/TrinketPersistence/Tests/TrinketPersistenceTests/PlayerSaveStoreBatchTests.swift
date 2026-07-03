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
        let store = PlayerSaveStore(fileStore: fileStore)
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
}
