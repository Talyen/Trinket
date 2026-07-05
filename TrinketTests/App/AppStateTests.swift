import TrinketContent
import TrinketPersistence
import XCTest
@testable import Trinket

@MainActor
final class AppStateTests: XCTestCase {
    private var directoryURL: URL!
    private let sync = LocalOnlyPlayerSaveSync()

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStateTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directoryURL)
        try await super.tearDown()
    }

    func testDefaultInitSelectsPlayTabWithFreshSave() {
        let state = makeAppState(environment: makeEnvironment())

        XCTAssertEqual(state.selectedTab, .play)
        XCTAssertEqual(state.roster.current, .freshStart)
        XCTAssertEqual(state.inventory.current, .freshStart)
    }

    func testLaunchTabOverridesDefaultTab() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-selectedTab", "homestead"])
        )

        XCTAssertEqual(state.selectedTab, .homestead)
    }

    func testHeroDetailLaunchScreenDefaultsToCollectionTab() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-launch-screen", "hero:knight"])
        )

        XCTAssertEqual(state.selectedTab, .collection)
        assertCollectionDetail(
            state.initialCollectionCombatantDetail,
            kind: .hero,
            combatantID: "knight"
        )
        XCTAssertNil(state.initialCollectionItemID)
    }

    func testPetDetailLaunchScreenExposesCollectionCombatantDetail() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-launch-screen", "pet:wolf"])
        )

        XCTAssertEqual(state.selectedTab, .collection)
        assertCollectionDetail(
            state.initialCollectionCombatantDetail,
            kind: .pet,
            combatantID: "wolf"
        )
    }

    func testItemDetailLaunchScreenExposesCollectionItemID() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-launch-screen", "item:shortsword-basic"])
        )

        XCTAssertEqual(state.selectedTab, .collection)
        XCTAssertNil(state.initialCollectionCombatantDetail)
        XCTAssertEqual(state.initialCollectionItemID, "shortsword-basic")
    }

    func testBattleLaunchScreenDefaultsToPlayTab() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-launch-screen", "battle"])
        )

        XCTAssertEqual(state.selectedTab, .play)
    }

    func testBattleLaunchScreenStartsStageOneOne() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-launch-screen", "battle"])
        )

        XCTAssertNotNil(state.battle.activeBattle)
        XCTAssertEqual(state.battle.activeBattle?.stageID, "chapter-1-stage-1")
    }

    func testSeedTestProgressPopulatesInventory() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-reset-state", "-seed-test-progress"])
        )

        XCTAssertFalse(state.inventory.current.items.isEmpty)
        XCTAssertTrue(state.inventory.current.items.contains { $0.displayName == "Longsword" })
        XCTAssertTrue(state.inventory.current.items.contains { $0.displayName == "Wand" })
    }

    func testOptionsLaunchScreenDefaultsToOptionsTab() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-launch-screen", "options"])
        )

        XCTAssertEqual(state.selectedTab, .options)
    }

    func testThemeOverrideAppliesToOptionsStore() {
        let defaults = UserDefaults.standard
        let previousTheme = defaults.string(forKey: "options.theme")
        defer {
            if let previousTheme {
                defaults.set(previousTheme, forKey: "options.theme")
            } else {
                defaults.removeObject(forKey: "options.theme")
            }
        }

        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-theme", "light"])
        )

        XCTAssertEqual(state.options.theme, .light)
    }

    func testResetStateWipesPersistedSave() throws {
        let fileStore = makeFileStore()
        var save = PlayerSave.fresh
        save.roster.gold = 99
        try fileStore.save(save)

        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-reset-state"]),
            fileStore: fileStore
        )

        XCTAssertEqual(state.roster.current, .freshStart)
        XCTAssertEqual(state.inventory.current, .freshStart)

        let reloadedStore = PlayerSaveStore(fileStore: fileStore)
        XCTAssertEqual(reloadedStore.roster, .freshStart)
    }

    func testSeedTestProgressAppliesDeterministicBaseline() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-seed-test-progress"]),
            fileStore: makeFileStore()
        )

        XCTAssertEqual(state.roster.current, .testSeed)
        XCTAssertEqual(state.inventory.current, .testSeed)
    }

    func testCompletedStagesAdvanceJourneyAndMarkRewardsClaimed() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-completed-stages", "chapter-1-stage-1"])
        )

        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-2")
        XCTAssertTrue(state.journey.current.claimedRewardStageIDs.contains("chapter-1-stage-1"))
    }

    func testUnknownCompletedStageIDsAreIgnored() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-completed-stages", "missing-stage"])
        )

        XCTAssertEqual(state.journey.current, .initial)
    }

    func testMapScrollTargetLaunchArgRequestsPlayMapScroll() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-map-scroll-target", "chapter-gate-placeholder-2"])
        )
        XCTAssertEqual(state.journey.mapScrollRequest?.targetID, "chapter-gate-placeholder-2")
    }

    func testCompleteStageUpdatesStoresAndRequestsMapScroll() throws {
        let state = makeAppState(environment: makeEnvironment())
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        let initialGold = state.roster.current.gold

        let scrollTarget = state.completeStage(
            stage,
            hero: state.roster.activeHero,
            pet: state.roster.activePet
        )

        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-2")
        XCTAssertTrue(state.journey.current.completedStageIDs.contains(stage.id))
        XCTAssertGreaterThan(state.roster.current.gold, initialGold)
        XCTAssertEqual(scrollTarget, "chapter-1-stage-2")
        XCTAssertEqual(state.journey.mapScrollRequest?.targetID, "chapter-1-stage-2")
        XCTAssertEqual(state.sessionState.mapScrollStageID, "chapter-1-stage-2")
    }

    private func makeFileStore() -> PlayerSaveFileStore {
        PlayerSaveFileStore(directoryURL: directoryURL)
    }

    private func makeEnvironment(arguments: [String] = []) -> AppEnvironment {
        AppEnvironment.parse(arguments: arguments, environment: [:])
    }

    private func makeAppState(
        environment: AppEnvironment,
        fileStore: PlayerSaveFileStore? = nil
    ) -> AppState {
        AppState(
            environment: environment,
            sync: sync,
            fileStore: fileStore ?? makeFileStore()
        )
    }

    private func assertCollectionDetail(
        _ selection: CombatantCollectionDetailSelection?,
        kind: CombatantCollectionDetailSelection.Kind,
        combatantID: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let selection else {
            XCTFail("Expected collection detail selection", file: file, line: line)
            return
        }

        switch selection.source {
        case let .collection(actualKind, actualID):
            XCTAssertEqual(actualKind, kind, file: file, line: line)
            XCTAssertEqual(actualID, combatantID, file: file, line: line)
        case .battleSnapshot:
            XCTFail("Expected collection detail, got battle snapshot", file: file, line: line)
        }
    }
}
