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
    }

    func testBattleLaunchScreenDefaultsToPlayTab() {
        let state = makeAppState(
            environment: makeEnvironment(arguments: ["-launch-screen", "battle"])
        )

        XCTAssertEqual(state.selectedTab, .play)
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

    func testResetStateWipesPersistedSave() {
        let fileStore = makeFileStore()
        var save = PlayerSave.fresh
        save.roster.gold = 99
        fileStore.save(save)

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
}
