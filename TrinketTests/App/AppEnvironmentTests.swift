import Testing
@testable import Trinket

struct AppEnvironmentTests {
    private static let emptyEnvironment: [String: String] = [:]

    @Test(arguments: AppTab.allCases)
    func selectedTabParsesKnownTabs(tab: AppTab) {
        let env = Self.parse(arguments: ["-selectedTab", tab.rawValue])
        #expect(env.launchTab == tab)
    }

    @Test(arguments: ["heroes", "pets", "inventory", "Heroes", "PETS"])
    func collectionTabAliasesMapToCollection(alias: String) {
        let env = Self.parse(arguments: ["-selectedTab", alias])
        #expect(env.launchTab == .collection, "Expected alias '\(alias)' to map to collection")
    }

    @Test func invalidSelectedTabReturnsNil() {
        let env = Self.parse(arguments: ["-selectedTab", "not-a-tab"])
        #expect(env.launchTab == nil)
    }

    @Test func launchScreenParsesHeroPetAndItemDetails() {
        #expect(
            Self.parse(arguments: ["-launch-screen", "hero:knight"]).launchScreen == .heroDetail("knight")
        )
        #expect(
            Self.parse(arguments: ["-launch-screen", "pet:bear"]).launchScreen == .petDetail("bear")
        )
        #expect(
            Self.parse(arguments: ["-launch-screen", "item:longsword-basic"]).launchScreen
                == .itemDetail("longsword-basic")
        )
    }

    @Test func launchScreenParsesOptionsAndBattle() {
        #expect(Self.parse(arguments: ["-launch-screen", "options"]).launchScreen == .options)
        #expect(Self.parse(arguments: ["-launch-screen", "battle"]).launchScreen == .battle)
    }

    @Test func launchScreenRejectsEmptyIDsAndUnknownKinds() {
        #expect(Self.parse(arguments: ["-launch-screen", "hero:"]).launchScreen == nil)
        #expect(Self.parse(arguments: ["-launch-screen", "unknown:foo"]).launchScreen == nil)
    }

    @Test func launchScreenIgnoresTrailingIDForOptions() {
        #expect(Self.parse(arguments: ["-launch-screen", "options:extra"]).launchScreen == .options)
    }

    @Test func resetStateFlag() {
        #expect(Self.parse(arguments: ["-reset-state"]).resetState)
        #expect(!Self.parse(arguments: []).resetState)
    }

    @Test func seedTestProgressFlag() {
        #expect(Self.parse(arguments: ["-seed-test-progress"]).seedTestProgress)
        #expect(!Self.parse(arguments: []).seedTestProgress)
    }

    @Test func disableCloudSyncFlag() {
        #expect(Self.parse(arguments: ["-disable-cloud-sync"]).disableCloudSync)
        #expect(!Self.parse(arguments: []).disableCloudSync)
    }

    @Test func disableAudioFlag() {
        #expect(Self.parse(arguments: ["-disable-audio"]).disableAudio)
        #expect(!Self.parse(arguments: []).disableAudio)
    }

    @Test func appearanceOverrideParsesKnownModes() {
        #expect(Self.parse(arguments: ["-appearance", "system"]).appearanceOverride == .system)
        #expect(Self.parse(arguments: ["-appearance", "Light"]).appearanceOverride == .light)
        #expect(Self.parse(arguments: ["-appearance", "dark"]).appearanceOverride == .dark)
    }

    @Test func invalidAppearanceOverrideReturnsNil() {
        #expect(Self.parse(arguments: ["-appearance", "not-a-mode"]).appearanceOverride == nil)
    }

    @Test func resetStateImplicitlyDisablesCloudSync() {
        #expect(Self.parse(arguments: ["-reset-state"]).disableCloudSync)
    }

    @Test func persistSaveImmediatelyFlag() {
        #expect(Self.parse(arguments: ["-persist-save-immediately"]).persistSaveImmediately)
        #expect(!Self.parse(arguments: []).persistSaveImmediately)
    }

    @Test func battleTickIntervalParsesExplicitValue() {
        let env = Self.parse(arguments: ["-battle-tick-interval", "0.25"])
        #expect(env.battleTickInterval == 0.25)
    }

    @Test func battleTickIntervalExplicitValueIsHonored() {
        let env = Self.parse(arguments: ["-battle-tick-interval", "0.4"])
        #expect(env.battleTickInterval == 0.4)
    }

    @Test func invalidBattleTickIntervalIgnored() {
        let env = Self.parse(arguments: ["-battle-tick-interval", "not-a-number"])
        #expect(env.battleTickInterval == nil)
    }

    @Test func completedStagesParsesCommaSeparatedIDs() {
        let env = Self.parse(arguments: ["-completed-stages", "chapter-1-stage-1,chapter-1-stage-2"])
        #expect(env.completedStageIDs == ["chapter-1-stage-1", "chapter-1-stage-2"])
    }

    @Test func completedStagesFiltersEmptySegments() {
        let env = Self.parse(arguments: ["-completed-stages", "chapter-1-stage-1,,chapter-1-stage-2,"])
        #expect(env.completedStageIDs == ["chapter-1-stage-1", "chapter-1-stage-2"])
    }

    @Test func mapScrollTargetParsesTargetID() {
        let env = Self.parse(arguments: ["-map-scroll-target", "chapter-gate-placeholder-2"])
        #expect(env.mapScrollTarget == "chapter-gate-placeholder-2")
    }

    @Test func mapScrollTargetRejectsEmptyValue() {
        let env = Self.parse(arguments: ["-map-scroll-target", ""])
        #expect(env.mapScrollTarget == nil)
    }

    @Test func noFlagsYieldsDefaultEnvironment() {
        let env = Self.parse(arguments: [])

        #expect(env.launchTab == nil)
        #expect(env.launchScreen == nil)
        #expect(!env.resetState)
        #expect(!env.seedTestProgress)
        #if targetEnvironment(simulator)
        #expect(env.disableCloudSync)
        #else
        #expect(!env.disableCloudSync)
        #endif
        #expect(!env.disableAudio)
        #expect(env.appearanceOverride == nil)
        #expect(env.completedStageIDs.isEmpty)
        #expect(env.mapScrollTarget == nil)
        #expect(env.battleTickInterval == nil)
        #expect(!env.persistSaveImmediately)
    }

    #if targetEnvironment(simulator)
    @Test func enableCloudSyncFlagOnSimulator() {
        let env = Self.parse(arguments: ["-enable-cloud-sync"])
        #expect(!env.disableCloudSync)
    }
    #endif

    private static func parse(
        arguments: [String],
        environment: [String: String]? = nil
    ) -> AppEnvironment {
        AppEnvironment.parse(arguments: arguments, environment: environment ?? emptyEnvironment)
    }
}
