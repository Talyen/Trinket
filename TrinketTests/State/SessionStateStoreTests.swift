import XCTest
@testable import Trinket

final class SessionStateStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SessionStateStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsWhenNoStoredValues() {
        let store = SessionStateStore(defaults: defaults)

        XCTAssertNil(store.selectedTab)
        XCTAssertNil(store.activeBattleStageID)
        XCTAssertNil(store.mapScrollStageID)
    }

    func testLoadsPreviouslyStoredTab() {
        defaults.set(AppTab.homestead.rawValue, forKey: "session.selectedTab")

        let store = SessionStateStore(defaults: defaults)

        XCTAssertEqual(store.selectedTab, .homestead)
    }

    func testLoadsPreviouslyStoredBattleStageID() {
        defaults.set("chapter-1-stage-3", forKey: "session.activeBattleStageID")

        let store = SessionStateStore(defaults: defaults)

        XCTAssertEqual(store.activeBattleStageID, "chapter-1-stage-3")
    }

    func testLoadsPreviouslyStoredMapScrollStageID() {
        defaults.set("chapter-2-stage-1", forKey: "session.mapScrollStageID")

        let store = SessionStateStore(defaults: defaults)

        XCTAssertEqual(store.mapScrollStageID, "chapter-2-stage-1")
    }

    func testSelectedTabPersistsOnChange() {
        let store = SessionStateStore(defaults: defaults)
        store.selectedTab = .options

        XCTAssertEqual(defaults.string(forKey: "session.selectedTab"), AppTab.options.rawValue)
        XCTAssertEqual(SessionStateStore(defaults: defaults).selectedTab, .options)
    }

    func testActiveBattleStageIDPersistsOnChange() {
        let store = SessionStateStore(defaults: defaults)
        store.activeBattleStageID = "chapter-1-stage-5"

        XCTAssertEqual(defaults.string(forKey: "session.activeBattleStageID"), "chapter-1-stage-5")
        XCTAssertEqual(SessionStateStore(defaults: defaults).activeBattleStageID, "chapter-1-stage-5")
    }

    func testMapScrollStageIDPersistsOnChange() {
        let store = SessionStateStore(defaults: defaults)
        store.mapScrollStageID = "chapter-3-gate"

        XCTAssertEqual(defaults.string(forKey: "session.mapScrollStageID"), "chapter-3-gate")
        XCTAssertEqual(SessionStateStore(defaults: defaults).mapScrollStageID, "chapter-3-gate")
    }

    func testNillingSelectedTabRemovesKey() {
        let store = SessionStateStore(defaults: defaults)
        store.selectedTab = .options
        store.selectedTab = nil

        XCTAssertNil(defaults.string(forKey: "session.selectedTab"))
    }

    func testClearBattleStateClearsBothBattleAndScrollKeys() {
        let store = SessionStateStore(defaults: defaults)
        store.activeBattleStageID = "chapter-1-stage-1"
        store.mapScrollStageID = "chapter-1-stage-2"

        store.clearBattleState()

        XCTAssertNil(store.activeBattleStageID)
        XCTAssertNil(store.mapScrollStageID)
    }

    func testClearBattleStateLeavesTabIntact() {
        let store = SessionStateStore(defaults: defaults)
        store.selectedTab = .homestead
        store.activeBattleStageID = "chapter-1-stage-1"

        store.clearBattleState()

        XCTAssertEqual(store.selectedTab, .homestead)
        XCTAssertNil(store.activeBattleStageID)
    }

    func testClearAllClearsAllKeys() {
        let store = SessionStateStore(defaults: defaults)
        store.selectedTab = .collection
        store.activeBattleStageID = "chapter-1-stage-1"
        store.mapScrollStageID = "chapter-1-stage-2"
        store.noteMapScrollFocus("chapter-1-stage-3")

        store.clearAll()

        XCTAssertNil(store.selectedTab)
        XCTAssertNil(store.activeBattleStageID)
        XCTAssertNil(store.mapScrollStageID)
        XCTAssertEqual(store.mapScrollNonce, 0)
    }

    func testNoteMapScrollFocusPersistsTargetAndBumpsNonce() {
        let store = SessionStateStore(defaults: defaults)

        store.noteMapScrollFocus("chapter-1-stage-2")

        XCTAssertEqual(store.mapScrollStageID, "chapter-1-stage-2")
        XCTAssertEqual(store.mapScrollNonce, 1)
        XCTAssertEqual(defaults.string(forKey: "session.mapScrollStageID"), "chapter-1-stage-2")
    }

    func testNoteMapScrollFocusCanForceNonceWhenTargetUnchanged() {
        let store = SessionStateStore(defaults: defaults)
        store.noteMapScrollFocus("chapter-1-stage-2")

        store.noteMapScrollFocus("chapter-1-stage-2", bumpEvenWhenUnchanged: true)

        XCTAssertEqual(store.mapScrollNonce, 2)
    }

    func testActiveBattleFieldsPersistAndLoad() {
        let store = SessionStateStore(defaults: defaults)
        XCTAssertNil(store.activeBattleSavedAt)
        XCTAssertNil(store.activeBattleSchemaVersion)
        
        store.activeBattleStageID = "chapter-1-stage-1"
        XCTAssertNotNil(store.activeBattleSavedAt)
        XCTAssertEqual(store.activeBattleSchemaVersion, SessionStateStore.currentSchemaVersion)
        
        let store2 = SessionStateStore(defaults: defaults)
        XCTAssertNotNil(store2.activeBattleSavedAt)
        XCTAssertEqual(store2.activeBattleSchemaVersion, SessionStateStore.currentSchemaVersion)
        
        store.activeBattleStageID = nil
        XCTAssertNil(store.activeBattleSavedAt)
        XCTAssertNil(store.activeBattleSchemaVersion)
        
        let store3 = SessionStateStore(defaults: defaults)
        XCTAssertNil(store3.activeBattleSavedAt)
        XCTAssertNil(store3.activeBattleSchemaVersion)
    }

    func testLastBackgroundedTimePersistsAndLoads() throws {
        let store = SessionStateStore(defaults: defaults)
        XCTAssertNil(store.lastBackgroundedTime)
        
        let date = Date()
        store.lastBackgroundedTime = date
        
        let store2 = SessionStateStore(defaults: defaults)
        let loadedDate = try XCTUnwrap(store2.lastBackgroundedTime)
        XCTAssertEqual(loadedDate.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.1)
    }

    func testViewedCombatantsPersistAndLoad() {
        let store = SessionStateStore(defaults: defaults)
        XCTAssertTrue(store.viewedCombatantIDs.isEmpty)
        
        store.markCombatantAsViewed(id: "knight")
        XCTAssertTrue(store.viewedCombatantIDs.contains("knight"))
        
        let store2 = SessionStateStore(defaults: defaults)
        XCTAssertTrue(store2.viewedCombatantIDs.contains("knight"))
    }
}
