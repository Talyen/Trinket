import Testing
import TrinketBattleFeature
import TrinketFeatureSupport
@testable import TrinketAppState

struct AppEnvironmentTests {
    @Test(arguments: ["-disable-cloud-sync", "-reset-state", "-seed-test-progress"], [false, true])
    func `local safety flags override cloud opt in and build default`(flag: String, cloudDefault: Bool) {
        #expect(Self.parse(arguments: ["-enable-cloud-sync", flag], cloudDefault: cloudDefault).disableCloudSync)
    }

    @Test(arguments: [false, true])
    func `runners override cloud opt in and build default`(cloudDefault: Bool) {
        #expect(Self.parse(
            arguments: ["-enable-cloud-sync"],
            environment: ["XCTestConfigurationFilePath": "isolated-tests"],
            cloudDefault: cloudDefault,
        ).disableCloudSync)
    }

    @Test(arguments: [false, true])
    func `cloud build default controls ordinary launch`(cloudDefault: Bool) {
        #expect(Self.parse(arguments: [], cloudDefault: cloudDefault).disableCloudSync == !cloudDefault)
    }

    @Test func `cloud launch opt in respects build configuration`() {
        #if DEBUG
        #expect(!Self.parse(arguments: ["-enable-cloud-sync"]).disableCloudSync)
        #else
        #expect(Self.parse(arguments: ["-enable-cloud-sync"]).disableCloudSync)
        #endif
    }

    private static let emptyEnvironment: [String: String] = [:]

    private static let selectedTabCases: [(String, AppTab?)] =
        AppTab.allCases.map { ($0.rawValue, $0) } + [
            ("heroes", .collection),
            ("companions", .collection),
            ("inventory", .collection),
            ("search", .collection),
            ("Heroes", .collection),
            ("COMPANIONS", .collection),
            ("SEARCH", .collection),
            ("not-a-tab", nil),
        ]

    @Test func `tab accessibility I ds match display names`() {
        #expect(AccessibilityID.Tab.play == AppTab.play.displayName)
        #expect(AccessibilityID.Tab.collection == AppTab.collection.displayName)
        #expect(AccessibilityID.Tab.homestead == AppTab.homestead.displayName)
        #expect(AccessibilityID.Tab.options == AppTab.options.displayName)
    }

    @Test(arguments: selectedTabCases)
    func `selected tab parses known tabs aliases and invalid input`(rawValue: String, expected: AppTab?) {
        let env = Self.parse(arguments: ["-selectedTab", rawValue])
        #expect(env.launchTab == expected)
    }

    @Test func `launch screen parsing covers details modes and boundaries`() {
        #expect(
            Self.parse(arguments: ["-launch-screen", "hero:knight"]).launchScreen == .heroDetail("knight"),
        )
        #expect(
            Self.parse(arguments: ["-launch-screen", "companion:bear"]).launchScreen == .companionDetail("bear"),
        )
        #expect(
            Self.parse(arguments: ["-launch-screen", "item:longsword-basic"]).launchScreen
                == .itemDetail("longsword-basic"),
        )
        #expect(Self.parse(arguments: ["-launch-screen", "options"]).launchScreen == .options)
        #expect(Self.parse(arguments: ["-launch-screen", "battle"]).launchScreen == .battle)
        #expect(
            Self.parse(arguments: ["-launch-screen", "battle-victory"]).launchScreen == .battleVictory,
        )
        #expect(Self.parse(arguments: ["-launch-screen", "shop"]).launchScreen == .shop)
        #expect(Self.parse(arguments: ["-launch-screen", "mystery"]).launchScreen == .mystery)

        #expect(Self.parse(arguments: ["-launch-screen", "hero:"]).launchScreen == nil)
        #expect(Self.parse(arguments: ["-launch-screen", "unknown:foo"]).launchScreen == nil)
        #expect(Self.parse(arguments: ["-launch-screen", "options:extra"]).launchScreen == .options)
        #expect(Self.parse(arguments: ["-launch-screen", ""]).launchScreen == nil)
        #expect(Self.parse(arguments: ["-launch-screen", ":"]).launchScreen == nil)
        #expect(Self.parse(arguments: ["-launch-screen", "::"]).launchScreen == nil)
    }

    @Test func `command line flags parse as semantic groups`() {
        let env = Self.parse(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-skip-starter-selection",
            "-disable-audio",
            "-completed-stages", "chapter-1-stage-1,,chapter-1-stage-2,",
            "-mystery-recruit-event", "recruit-ranger",
            "-battle-tick-interval", "60",
            "-launch-preparation-delay", "8",
            "-starting-gold", "200",
            "-enable-frame-metrics",
            "-battle-performance-scenario", "engine-feedback",
        ])
        #expect(env.resetState)
        #expect(env.seedTestProgress)
        #expect(env.skipStarterSelection)
        #expect(env.disableCloudSync)
        #expect(env.disableAudio)
        #expect(env.completedStageIDs == ["chapter-1-stage-1", "chapter-1-stage-2"])
        #expect(env.mysteryRecruitEventID == "recruit-ranger")
        #expect(env.battleTickInterval == 60)
        #expect(env.startingGold == 200)
        #expect(env.enableFrameMetrics)
        #if DEBUG
        #expect(env.launchPreparationDelay == 8)
        #expect(env.battlePerformanceScenario == .engineFeedback)
        #else
        #expect(env.launchPreparationDelay == 0)
        #expect(env.battlePerformanceScenario == nil)
        #endif
        #expect(
            Self.parse(arguments: ["-battle-performance-scenario", "unknown"]).battlePerformanceScenario == nil,
        )
        #expect(Self.parse(arguments: ["-battle-tick-interval", "nope"]).battleTickInterval == nil)
        #expect(Self.parse(arguments: ["-starting-gold", "nope"]).startingGold == nil)
    }

    @Test func `no flags yields default environment`() {
        let env = Self.parse(arguments: [])

        #expect(env.launchTab == nil)
        #expect(env.launchScreen == nil)
        #expect(!env.resetState)
        #expect(!env.seedTestProgress)
        #expect(!env.skipStarterSelection)
        #expect(env.disableCloudSync)
        #expect(!env.disableAudio)
        #expect(env.completedStageIDs.isEmpty)
        #expect(env.mysteryRecruitEventID == nil)
        #expect(env.battleTickInterval == nil)
        #expect(env.startingGold == nil)
        #expect(!env.enableFrameMetrics)
        #expect(env.battlePerformanceScenario == nil)
    }

    private static func parse(
        arguments: [String],
        environment: [String: String]? = nil,
        cloudDefault: Bool = false,
    ) -> AppEnvironment {
        AppEnvironment.parse(
            arguments: arguments,
            environment: environment ?? emptyEnvironment,
            cloudSyncEnabledByDefault: cloudDefault,
        )
    }
}
