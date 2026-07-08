import Testing
import TrinketContent
import TrinketPersistence
@testable import Trinket

@MainActor
final class AppStateTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func defaultInitSelectsPlayTabWithFreshSave() {
        let state = context.makeAppState(environment: context.makeEnvironment())

        #expect(state.selectedTab == .play)
        #expect(state.roster.current == .freshStart)
        #expect(state.inventory.current == .freshStart)
    }

    @Test func launchTabOverridesDefaultTab() {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-selectedTab", "homestead"])
        )

        #expect(state.selectedTab == .homestead)
    }

    @Test func heroDetailLaunchScreenDefaultsToCollectionTab() {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "hero:knight"])
        )

        #expect(state.selectedTab == .collection)
        assertCollectionDetail(
            state.initialCollectionCombatantDetail,
            kind: .hero,
            combatantID: "knight"
        )
        #expect(state.initialCollectionItemID == nil)
    }

    @Test func petDetailLaunchScreenExposesCollectionCombatantDetail() {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "pet:wolf"])
        )

        #expect(state.selectedTab == .collection)
        assertCollectionDetail(
            state.initialCollectionCombatantDetail,
            kind: .pet,
            combatantID: "wolf"
        )
    }

    @Test func itemDetailLaunchScreenExposesCollectionItemID() {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "item:shortsword-basic"])
        )

        #expect(state.selectedTab == .collection)
        #expect(state.initialCollectionCombatantDetail == nil)
        #expect(state.initialCollectionItemID == "shortsword-basic")
    }

    @Test func battleLaunchScreenDefaultsToPlayTab() {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "battle"])
        )

        #expect(state.selectedTab == .play)
    }

    @Test func battleLaunchScreenStartsStageOneOne() throws {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "battle"])
        )

        let activeBattle = try #require(state.battle.activeBattle)
        #expect(activeBattle.stageID == "chapter-1-stage-1")
    }

    @Test func seedTestProgressPopulatesInventory() {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-reset-state", "-seed-test-progress"])
        )

        #expect(!(state.inventory.current.items.isEmpty))
        #expect(state.inventory.current.items.contains { $0.displayName == "Longsword" })
        #expect(state.inventory.current.items.contains { $0.displayName == "Wand" })
    }

    @Test func optionsLaunchScreenDefaultsToOptionsTab() {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "options"])
        )

        #expect(state.selectedTab == .options)
    }

    @Test func appearanceOverrideAppliesToOptionsStore() {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-appearance", "dark"])
        )

        #expect(state.options.appearance == .dark)
    }

    @Test func resetStateWipesPersistedSave() throws {
        var save = PlayerSave.fresh
        save.roster.gold = 99
        let firstStore = PlayerSaveStore(
            storeURL: SaveTestSupport.makeStoreURL(directoryURL: context.directoryURL),
            disableCloudSync: true
        )
        try firstStore.performBatchMutation { $0 = save }

        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-reset-state"])
        )

        #expect(state.roster.current == .freshStart)
        #expect(state.inventory.current == .freshStart)

        let reloadedStore = PlayerSaveStore(
            storeURL: SaveTestSupport.makeStoreURL(directoryURL: context.directoryURL),
            disableCloudSync: true
        )
        #expect(reloadedStore.roster == .freshStart)
    }

    @Test func seedTestProgressAppliesDeterministicBaseline() {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-seed-test-progress"])
        )

        #expect(state.roster.current == .testSeed)
        #expect(state.inventory.current == .testSeed)
    }

    @Test func completedStagesAdvanceJourneyAndMarkRewardsClaimed() {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-completed-stages", "chapter-1-stage-1"])
        )

        #expect(state.journey.current.activeStageID == "chapter-1-stage-2")
        #expect(state.journey.current.claimedRewardStageIDs.contains("chapter-1-stage-1"))
    }

    @Test func unknownCompletedStageIDsAreIgnored() {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-completed-stages", "missing-stage"])
        )

        #expect(state.journey.current == .initial)
    }

    @Test func mapScrollTargetLaunchArgSetsSessionScrollFocus() {
        let state = context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-map-scroll-target", "chapter-gate-placeholder-2"])
        )
        #expect(state.mapScrollStageID == "chapter-gate-placeholder-2")
        #expect(state.mapScrollNonce > 0)
    }

    @Test func completeStageUpdatesStoresAndMapScrollFocus() throws {
        let state = context.makeAppState(environment: context.makeEnvironment())
        let stage = try #require(GameContent.chapters[0].stages.first)
        let initialGold = state.roster.current.gold

        let scrollTarget = state.completeStage(
            stage,
            hero: state.roster.activeHero,
            pet: state.roster.activePet
        )

        #expect(state.journey.current.activeStageID == "chapter-1-stage-2")
        #expect(state.journey.current.completedStageIDs.contains(stage.id))
        #expect(state.roster.current.gold > initialGold)
        #expect(scrollTarget == "chapter-1-stage-2")
        #expect(state.mapScrollStageID == "chapter-1-stage-2")
        #expect(state.mapScrollNonce > 0)
    }

    private func assertCollectionDetail(
        _ detail: CombatantDetailContext?,
        kind: CombatantDetailContext.Kind,
        combatantID: String,
        sourceLocation: SourceLocation = #sourceLocation
    ) {
        guard let detail else {
            Issue.record(
                "Expected collection detail context",
                sourceLocation: sourceLocation
            )
            return
        }

        #expect(detail.kind == kind, sourceLocation: sourceLocation)
        #expect(detail.combatantID == combatantID, sourceLocation: sourceLocation)
    }
}
