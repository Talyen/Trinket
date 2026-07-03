import XCTest
import TrinketContent
@testable import TrinketPersistence

@MainActor
final class PlayerJourneyStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "PlayerJourneyStoreTests")
    }

    override func tearDown() async throws {
        SaveTestSupport.removeTempDirectory(directoryURL)
        try await super.tearDown()
    }

    func testRequestMapScrollSetsTargetID() {
        let journeyStore = PlayerJourneyStore(saveStore: SaveTestSupport.makeSaveStore(directoryURL: directoryURL))

        journeyStore.requestMapScroll(to: "chapter-1-stage-2")

        XCTAssertEqual(journeyStore.mapScrollRequest?.targetID, "chapter-1-stage-2")
    }

    func testClearMapScrollRequestRemovesMatchingRequest() throws {
        let journeyStore = PlayerJourneyStore(saveStore: SaveTestSupport.makeSaveStore(directoryURL: directoryURL))
        journeyStore.requestMapScroll(to: "chapter-1-stage-3")
        let request = try XCTUnwrap(journeyStore.mapScrollRequest)

        journeyStore.clearMapScrollRequest(request)

        XCTAssertNil(journeyStore.mapScrollRequest)
    }

    func testClearMapScrollRequestIgnoresStaleRequest() {
        let journeyStore = PlayerJourneyStore(saveStore: SaveTestSupport.makeSaveStore(directoryURL: directoryURL))
        journeyStore.requestMapScroll(to: "chapter-1-stage-3")
        let staleRequest = MapScrollRequest(targetID: "chapter-1-stage-1")

        journeyStore.clearMapScrollRequest(staleRequest)

        XCTAssertEqual(journeyStore.mapScrollRequest?.targetID, "chapter-1-stage-3")
    }

    func testCompleteStageWriteThroughToSaveStore() throws {
        let journeyStore = PlayerJourneyStore(saveStore: SaveTestSupport.makeSaveStore(directoryURL: directoryURL))
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)

        journeyStore.complete(stage, in: GameContent.chapters)

        let reloaded = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        XCTAssertEqual(reloaded.journey.activeStageID, "chapter-1-stage-2")
        XCTAssertTrue(reloaded.journey.completedStageIDs.contains(stage.id))
    }

    func testMarkRewardsClaimedWriteThroughToSaveStore() throws {
        let journeyStore = PlayerJourneyStore(saveStore: SaveTestSupport.makeSaveStore(directoryURL: directoryURL))
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        journeyStore.complete(stage, in: GameContent.chapters)

        journeyStore.markRewardsClaimed(for: stage)

        let reloaded = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        XCTAssertTrue(reloaded.journey.claimedRewardStageIDs.contains(stage.id))
    }
}
