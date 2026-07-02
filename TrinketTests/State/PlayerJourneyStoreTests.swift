import XCTest
@testable import Trinket

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
}
