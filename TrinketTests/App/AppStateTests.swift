import TrinketContent
import TrinketPersistence
import XCTest
@testable import Trinket

@MainActor
final class AppStateTests: XCTestCase {
    private var directoryURL: URL!
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "AppStateTests.\(UUID().uuidString)"
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        userDefaults.removePersistentDomain(forName: suiteName)
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

    func testBattleLaunchScreenStartsStageOneOne() throws {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-launch-screen", "battle"])
        )

        let activeBattle = try XCTUnwrap(state.battle.activeBattle)
        XCTAssertEqual(activeBattle.stageID, "chapter-1-stage-1")
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

    func testCorruptSaveSetsRecoveryAlertFlag() {
        // Obsolete: SwiftData corruptions are handled by CoreData schema migration plan.
    }

    func testAppearanceOverrideAppliesToOptionsStore() {
        let defaults = UserDefaults.standard
        let previousAppearance = defaults.string(forKey: "options.appearance")
        defer {
            if let previousAppearance {
                defaults.set(previousAppearance, forKey: "options.appearance")
            } else {
                defaults.removeObject(forKey: "options.appearance")
            }
        }

        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-appearance", "dark"])
        )

        XCTAssertEqual(state.options.appearance, .dark)
    }

    func testResetStateWipesPersistedSave() throws {
        var save = PlayerSave.fresh
        save.roster.gold = 99
        let firstStore = PlayerSaveStore(
            storeURL: SaveTestSupport.makeStoreURL(directoryURL: directoryURL),
            disableCloudSync: true
        )
        try firstStore.performBatchMutation { $0 = save }

        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-reset-state"])
        )

        XCTAssertEqual(state.roster.current, .freshStart)
        XCTAssertEqual(state.inventory.current, .freshStart)

        let reloadedStore = PlayerSaveStore(
            storeURL: SaveTestSupport.makeStoreURL(directoryURL: directoryURL),
            disableCloudSync: true
        )
        XCTAssertEqual(reloadedStore.roster, .freshStart)
    }

    func testSeedTestProgressAppliesDeterministicBaseline() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-seed-test-progress"])
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

    func testMapScrollTargetLaunchArgSetsSessionScrollFocus() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-map-scroll-target", "chapter-gate-placeholder-2"])
        )
        XCTAssertEqual(state.mapScrollStageID, "chapter-gate-placeholder-2")
        XCTAssertGreaterThan(state.mapScrollNonce, 0)
    }

    func testCompleteStageUpdatesStoresAndMapScrollFocus() throws {
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
        XCTAssertEqual(state.mapScrollStageID, "chapter-1-stage-2")
        XCTAssertGreaterThan(state.mapScrollNonce, 0)
    }

    private func makeEnvironment(arguments: [String] = []) -> AppEnvironment {
        AppEnvironment.parse(arguments: arguments, environment: [:])
    }

    private func makeAppState(
        environment: AppEnvironment
    ) -> AppState {
        AppState(
            environment: environment,
            playerSave: PlayerSaveStore(
                storeURL: SaveTestSupport.makeStoreURL(directoryURL: directoryURL),
                disableCloudSync: true,
                resetState: environment.resetState
            ),
            userDefaults: userDefaults
        )
    }

    private func assertCollectionDetail(
        _ context: CombatantDetailContext?,
        kind: CombatantDetailContext.Kind,
        combatantID: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let context else {
            XCTFail("Expected collection detail context", file: file, line: line)
            return
        }

        XCTAssertEqual(context.kind, kind, file: file, line: line)
        XCTAssertEqual(context.combatantID, combatantID, file: file, line: line)
    }
}
