import XCTest
@testable import Trinket

final class AppEnvironmentTests: XCTestCase {
    private let emptyEnvironment: [String: String] = [:]

    func testSelectedTabParsesKnownTabs() {
        for tab in AppTab.allCases {
            let env = parse(arguments: ["-selectedTab", tab.rawValue])
            XCTAssertEqual(env.launchTab, tab)
        }
    }

    func testCollectionTabAliasesMapToCollection() {
        for alias in ["heroes", "pets", "inventory", "Heroes", "PETS"] {
            let env = parse(arguments: ["-selectedTab", alias])
            XCTAssertEqual(env.launchTab, .collection, "Expected alias '\(alias)' to map to collection")
        }
    }

    func testInvalidSelectedTabReturnsNil() {
        let env = parse(arguments: ["-selectedTab", "not-a-tab"])
        XCTAssertNil(env.launchTab)
    }

    func testLaunchScreenParsesHeroPetAndItemDetails() {
        XCTAssertEqual(
            parse(arguments: ["-launch-screen", "hero:knight"]).launchScreen,
            .heroDetail("knight")
        )
        XCTAssertEqual(
            parse(arguments: ["-launch-screen", "pet:bear"]).launchScreen,
            .petDetail("bear")
        )
        XCTAssertEqual(
            parse(arguments: ["-launch-screen", "item:longsword-basic"]).launchScreen,
            .itemDetail("longsword-basic")
        )
    }

    func testLaunchScreenParsesOptionsAndBattle() {
        XCTAssertEqual(parse(arguments: ["-launch-screen", "options"]).launchScreen, .options)
        XCTAssertEqual(parse(arguments: ["-launch-screen", "battle"]).launchScreen, .battle)
    }

    func testLaunchScreenRejectsEmptyIDsAndUnknownKinds() {
        XCTAssertNil(parse(arguments: ["-launch-screen", "hero:"]).launchScreen)
        XCTAssertNil(parse(arguments: ["-launch-screen", "unknown:foo"]).launchScreen)
    }

    func testLaunchScreenIgnoresTrailingIDForOptions() {
        XCTAssertEqual(parse(arguments: ["-launch-screen", "options:extra"]).launchScreen, .options)
    }

    func testResetStateFlag() {
        XCTAssertTrue(parse(arguments: ["-reset-state"]).resetState)
        XCTAssertFalse(parse(arguments: []).resetState)
    }

    func testSeedTestProgressFlag() {
        XCTAssertTrue(parse(arguments: ["-seed-test-progress"]).seedTestProgress)
        XCTAssertFalse(parse(arguments: []).seedTestProgress)
    }

    func testDisableCloudSyncFlag() {
        XCTAssertTrue(parse(arguments: ["-disable-cloud-sync"]).disableCloudSync)
        XCTAssertFalse(parse(arguments: []).disableCloudSync)
    }

    func testDisableAudioFlag() {
        XCTAssertTrue(parse(arguments: ["-disable-audio"]).disableAudio)
        XCTAssertFalse(parse(arguments: []).disableAudio)
    }

    func testThemeOverrideParsesKnownThemes() {
        XCTAssertEqual(parse(arguments: ["-theme", "dark"]).themeOverride, .dark)
        XCTAssertEqual(parse(arguments: ["-theme", "Light"]).themeOverride, .light)
        XCTAssertEqual(parse(arguments: ["-theme", "system"]).themeOverride, .system)
    }

    func testInvalidThemeOverrideReturnsNil() {
        XCTAssertNil(parse(arguments: ["-theme", "not-a-theme"]).themeOverride)
    }

    func testResetStateImplicitlyDisablesCloudSync() {
        XCTAssertTrue(parse(arguments: ["-reset-state"]).disableCloudSync)
    }

    func testRunningUnderXCTestDisablesCloudSync() {
        let env = parse(
            arguments: [],
            environment: ["XCTestConfigurationFilePath": "/tmp/TrinketTests.xctest"]
        )
        XCTAssertTrue(env.disableCloudSync)
    }

    func testRunningUnderXCTestDisablesAudio() {
        let env = parse(
            arguments: [],
            environment: ["XCTestConfigurationFilePath": "/tmp/TrinketTests.xctest"]
        )
        XCTAssertTrue(env.disableAudio)
    }

    func testCompletedStagesParsesCommaSeparatedIDs() {
        let env = parse(arguments: ["-completed-stages", "chapter-1-stage-1,chapter-1-stage-2"])
        XCTAssertEqual(env.completedStageIDs, ["chapter-1-stage-1", "chapter-1-stage-2"])
    }

    func testCompletedStagesFiltersEmptySegments() {
        let env = parse(arguments: ["-completed-stages", "chapter-1-stage-1,,chapter-1-stage-2,"])
        XCTAssertEqual(env.completedStageIDs, ["chapter-1-stage-1", "chapter-1-stage-2"])
    }

    func testNoFlagsYieldsDefaultEnvironment() {
        let env = parse(arguments: [])

        XCTAssertNil(env.launchTab)
        XCTAssertNil(env.launchScreen)
        XCTAssertFalse(env.resetState)
        XCTAssertFalse(env.seedTestProgress)
        XCTAssertFalse(env.disableCloudSync)
        XCTAssertFalse(env.disableAudio)
        XCTAssertNil(env.themeOverride)
        XCTAssertTrue(env.completedStageIDs.isEmpty)
    }

    private func parse(
        arguments: [String],
        environment: [String: String]? = nil
    ) -> AppEnvironment {
        AppEnvironment.parse(arguments: arguments, environment: environment ?? emptyEnvironment)
    }
}
