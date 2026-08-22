import Testing
import TrinketBattleFeature
import TrinketFeatureSupport
@testable import TrinketAppState

struct AppEnvironmentTests {
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

    @Test(arguments: selectedTabCases)
    func selectedTabParsesKnownTabsAliasesAndInvalidInput(rawValue: String, expected: AppTab?) {
        let env = Self.parse(arguments: ["-selectedTab", rawValue])
        #expect(env.launchTab == expected)
    }

    @Test func launchScreenParsingCoversDetailsModesAndBoundaries() {
        #expect(
            Self.parse(arguments: ["-launch-screen", "hero:knight"]).launchScreen == .heroDetail("knight")
        )
        #expect(
            Self.parse(arguments: ["-launch-screen", "companion:bear"]).launchScreen == .companionDetail("bear")
        )
        #expect(
            Self.parse(arguments: ["-launch-screen", "item:longsword-basic"]).launchScreen
                == .itemDetail("longsword-basic")
        )
        #expect(Self.parse(arguments: ["-launch-screen", "options"]).launchScreen == .options)
        #expect(Self.parse(arguments: ["-launch-screen", "battle"]).launchScreen == .battle)
        #expect(
            Self.parse(arguments: ["-launch-screen", "battle-victory"]).launchScreen == .battleVictory
        )
        #expect(Self.parse(arguments: ["-launch-screen", "shop"]).launchScreen == .shop)
        #expect(Self.parse(arguments: ["-launch-screen", "mystery"]).launchScreen == .mystery)

        #expect(Self.parse(arguments: ["-launch-screen", "hero:"]).launchScreen == nil)
        #expect(Self.parse(arguments: ["-launch-screen", "unknown:foo"]).launchScreen == nil)
        #expect(Self.parse(arguments: ["-launch-screen", "options:extra"]).launchScreen == .options)
        // split omits empty subsequences; empty / colon-only values must not crash.
        #expect(Self.parse(arguments: ["-launch-screen", ""]).launchScreen == nil)
        #expect(Self.parse(arguments: ["-launch-screen", ":"]).launchScreen == nil)
        #expect(Self.parse(arguments: ["-launch-screen", "::"]).launchScreen == nil)
    }

    @Test func commandLineFlagsParseAsSemanticGroups() {
        let env = Self.parse(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-skip-starter-selection",
            "-disable-audio",
            "-persist-save-immediately",
            "-completed-stages", "chapter-1-stage-1,,chapter-1-stage-2,",
            "-mystery-recruit-event", "recruit-ranger",
            "-starter-roulette-seed", "7",
            "-battle-tick-interval", "60",
            "-starting-gold", "200",
            "-enable-frame-metrics",
            "-battle-performance-scenario", "engine-feedback",
        ])
        #expect(env.resetState)
        #expect(env.seedTestProgress)
        #expect(env.skipStarterSelection)
        #expect(env.disableCloudSync)
        #expect(env.disableAudio)
        #expect(env.persistSaveImmediately)
        #expect(env.completedStageIDs == ["chapter-1-stage-1", "chapter-1-stage-2"])
        #expect(env.mysteryRecruitEventID == "recruit-ranger")
        #expect(env.starterRouletteSeed == 7)
        #expect(env.battleTickInterval == 60)
        #expect(env.startingGold == 200)
        #expect(env.enableFrameMetrics)
        #expect(env.battlePerformanceScenario == .engineFeedback)

        #expect(!Self.parse(arguments: ["-enable-cloud-sync"]).disableCloudSync)
        #expect(
            Self.parse(arguments: ["-battle-performance-scenario", "unknown"]).battlePerformanceScenario == nil
        )
        #expect(Self.parse(arguments: ["-battle-tick-interval", "nope"]).battleTickInterval == nil)
        #expect(Self.parse(arguments: ["-starting-gold", "nope"]).startingGold == nil)
    }

    @Test func noFlagsYieldsDefaultEnvironment() {
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
        #expect(env.starterRouletteSeed == nil)
        #expect(env.battleTickInterval == nil)
        #expect(env.startingGold == nil)
        #expect(!env.persistSaveImmediately)
        #expect(!env.enableFrameMetrics)
        #expect(env.battlePerformanceScenario == nil)
    }

    private static func parse(
        arguments: [String],
        environment: [String: String]? = nil
    ) -> AppEnvironment {
        AppEnvironment.parse(arguments: arguments, environment: environment ?? emptyEnvironment)
    }
}
