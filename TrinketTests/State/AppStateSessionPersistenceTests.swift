import TrinketContent
import TrinketPersistence
import XCTest
@testable import Trinket

@MainActor
final class AppStateSessionPersistenceTests: XCTestCase {
    private var directoryURL: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "AppStateSessionPersistenceTests")
        suiteName = "AppStateSessionPersistenceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        SaveTestSupport.removeTempDirectory(directoryURL)
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try await super.tearDown()
    }

    private func makeState() -> AppState {
        AppTestSupport.makeAppState(directoryURL: directoryURL, userDefaults: defaults)
    }

    func testDefaultsWhenNoStoredValues() {
        let state = makeState()

        XCTAssertEqual(state.selectedTab, .play)
        XCTAssertNil(state.activeBattleStageID)
        XCTAssertNil(state.mapScrollStageID)
    }

    func testLoadsPreviouslyStoredTab() {
        defaults.set(AppTab.homestead.rawValue, forKey: AppState.sessionTabKey)

        let state = makeState()

        XCTAssertEqual(state.selectedTab, .homestead)
    }

    func testLoadsPreviouslyStoredBattleStageID() {
        defaults.set("chapter-1-stage-3", forKey: AppState.activeBattleStageIDKey)

        let state = makeState()

        XCTAssertEqual(state.activeBattleStageID, "chapter-1-stage-3")
    }

    func testLoadsPreviouslyStoredMapScrollStageID() {
        defaults.set("chapter-2-stage-1", forKey: AppState.mapScrollStageIDKey)

        let state = makeState()

        XCTAssertEqual(state.mapScrollStageID, "chapter-2-stage-1")
    }

    func testSelectedTabPersistsOnChange() {
        let state = makeState()
        state.selectedTab = .options

        XCTAssertEqual(defaults.string(forKey: AppState.sessionTabKey), AppTab.options.rawValue)
        XCTAssertEqual(makeState().selectedTab, .options)
    }

    func testActiveBattleStageIDPersistsOnChange() {
        let state = makeState()
        state.activeBattleStageID = "chapter-1-stage-5"

        XCTAssertEqual(defaults.string(forKey: AppState.activeBattleStageIDKey), "chapter-1-stage-5")
        XCTAssertEqual(makeState().activeBattleStageID, "chapter-1-stage-5")
    }

    func testMapScrollStageIDPersistsOnChange() {
        let state = makeState()
        state.mapScrollStageID = "chapter-3-gate"

        XCTAssertEqual(defaults.string(forKey: AppState.mapScrollStageIDKey), "chapter-3-gate")
        XCTAssertEqual(makeState().mapScrollStageID, "chapter-3-gate")
    }

    func testClearSessionBattleStateClearsBothBattleAndScrollKeys() {
        let state = makeState()
        state.activeBattleStageID = "chapter-1-stage-1"
        state.mapScrollStageID = "chapter-1-stage-2"

        state.clearSessionBattleState()

        XCTAssertNil(state.activeBattleStageID)
        XCTAssertNil(state.mapScrollStageID)
    }

    func testClearSessionBattleStateLeavesTabIntact() {
        let state = makeState()
        state.selectedTab = .homestead
        state.activeBattleStageID = "chapter-1-stage-1"

        state.clearSessionBattleState()

        XCTAssertEqual(state.selectedTab, .homestead)
        XCTAssertNil(state.activeBattleStageID)
    }

    func testNoteMapScrollFocusPersistsTargetAndBumpsNonce() {
        let state = makeState()

        state.noteMapScrollFocus("chapter-1-stage-2")

        XCTAssertEqual(state.mapScrollStageID, "chapter-1-stage-2")
        XCTAssertEqual(state.mapScrollNonce, 1)
        XCTAssertEqual(defaults.string(forKey: AppState.mapScrollStageIDKey), "chapter-1-stage-2")
    }

    func testNoteMapScrollFocusCanForceNonceWhenTargetUnchanged() {
        let state = makeState()
        state.noteMapScrollFocus("chapter-1-stage-2")

        state.noteMapScrollFocus("chapter-1-stage-2", bumpEvenWhenUnchanged: true)

        XCTAssertEqual(state.mapScrollNonce, 2)
    }
}
