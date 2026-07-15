import Testing
@testable import Trinket

struct AppEnvironmentTests {
    private static let emptyEnvironment: [String: String] = [:]

    @Test(arguments: AppTab.allCases)
    func selectedTabParsesKnownTabs(tab: AppTab) {
        let env = Self.parse(arguments: ["-selectedTab", tab.rawValue])
        #expect(env.launchTab == tab)
    }

    @Test(arguments: ["heroes", "companions", "inventory", "search", "Heroes", "COMPANIONS", "SEARCH"])
    func collectionTabAliasesMapToCollection(alias: String) {
        let env = Self.parse(arguments: ["-selectedTab", alias])
        #expect(env.launchTab == .collection, "Expected alias '\(alias)' to map to collection")
    }

    @Test func invalidSelectedTabReturnsNil() {
        let env = Self.parse(arguments: ["-selectedTab", "not-a-tab"])
        #expect(env.launchTab == nil)
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
    }

    @Test func commandLineFlagsParseAsSemanticGroups() {
        let env = Self.parse(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-disable-audio",
            "-persist-save-immediately",
            "-battle-tick-interval", "0.4",
            "-completed-stages", "chapter-1-stage-1,,chapter-1-stage-2,",
            "-map-scroll-target", "chapter-gate-placeholder-2",
            "-mystery-recruit-event", "recruit-knight",
            "-enable-frame-metrics",
            "-battle-performance-scenario", "dense-feedback"
        ])
        #expect(env.resetState)
        #expect(env.seedTestProgress)
        #expect(env.disableCloudSync)
        #expect(env.disableAudio)
        #expect(env.persistSaveImmediately)
        #expect(env.battleTickInterval == 0.4)
        #expect(env.completedStageIDs == ["chapter-1-stage-1", "chapter-1-stage-2"])
        #expect(env.mapScrollTarget == "chapter-gate-placeholder-2")
        #expect(env.mysteryRecruitEventID == "recruit-knight")
        #expect(env.enableFrameMetrics)
        #expect(env.battlePerformanceScenario == .denseFeedback)

        #expect(Self.parse(arguments: ["-battle-tick-interval", "not-a-number"]).battleTickInterval == nil)
        #expect(Self.parse(arguments: ["-map-scroll-target", ""]).mapScrollTarget == nil)
        #expect(!Self.parse(arguments: ["-enable-cloud-sync"]).disableCloudSync)
        #expect(
            Self.parse(arguments: ["-battle-performance-scenario", "unknown"]).battlePerformanceScenario == nil
        )
    }

    @Test func noFlagsYieldsDefaultEnvironment() {
        let env = Self.parse(arguments: [])

        #expect(env.launchTab == nil)
        #expect(env.launchScreen == nil)
        #expect(!env.resetState)
        #expect(!env.seedTestProgress)
        #expect(env.disableCloudSync)
        #expect(!env.disableAudio)
        #expect(env.completedStageIDs.isEmpty)
        #expect(env.mapScrollTarget == nil)
        #expect(env.mysteryRecruitEventID == nil)
        #expect(env.battleTickInterval == nil)
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
