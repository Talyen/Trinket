import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence
import TrinketTestSupport
@testable import TrinketAppState

@MainActor
struct AppStateTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func defaultInitSelectsPlayTabWithFreshSave() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())

        #expect(state.selectedTab == .play)
        #expect(state.playerSave.roster == .freshStart)
        #expect(state.playerSave.roster.activeHeroID == "knight")
        #expect(state.playerSave.roster.activeCompanionID == "wolf")
        #expect(state.playerSave.inventory == .freshStart)
    }

    @Test func launchTabOverridesDefaultTabAndSurvivesForeground() throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-selectedTab", "homestead"])
        )

        #expect(state.selectedTab == .homestead)
        state.reconcileShellState(.scenePhaseChanged, scenePhase: .active)
        #expect(state.selectedTab == .homestead)

        state.selectedTab = .collection
        state.reconcileShellState(.scenePhaseChanged, scenePhase: .background)
        state.reconcileShellState(.scenePhaseChanged, scenePhase: .active)
        #expect(state.selectedTab == .collection)
    }

    @Test func scenePhaseSuspendsAndResumesBattleAutoEnd() throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "battle"])
        )
        #expect(state.battle.activeBattle != nil)
        #expect(!state.battle.isSuspendedForScenePhase)

        state.reconcileShellState(.scenePhaseChanged, scenePhase: .inactive)
        #expect(state.battle.isSuspendedForScenePhase)

        state.reconcileShellState(.scenePhaseChanged, scenePhase: .background)
        #expect(state.battle.isSuspendedForScenePhase)

        state.reconcileShellState(.scenePhaseChanged, scenePhase: .active)
        #expect(!state.battle.isSuspendedForScenePhase)
    }

    @Test func scenePhaseFlushesDeferredPlayerSaveSynchronously() throws {
        let storeURL = SaveTestSupport.makeStoreURL(directoryURL: context.directoryURL)
        let playerSave = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: false
        )
        let state = try context.makeAppState(playerSave: playerSave)
        let goldBefore = state.playerSave.roster.gold
        var updatedRoster = state.playerSave.roster
        updatedRoster.grantGold(13)
        state.playerSave.roster = updatedRoster

        state.reconcileShellState(.scenePhaseChanged, scenePhase: .background)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        #expect(reloaded.roster.gold == goldBefore + 13)
        #expect(playerSave.lastPersistenceError == nil)
    }

    @Test func collectionDetailLaunchScreensMapToCollectionPresentations() throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "hero:knight"])
        )

        #expect(state.selectedTab == .collection)
        guard case let .collectionCombatant(detail) = state.pendingCollectionPresentation else {
            Issue.record("Expected pending collection combatant presentation")
            return
        }
        assertCollectionDetail(
            detail,
            kind: .hero,
            combatantID: "knight"
        )

        let companionState = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "companion:wolf"])
        )

        #expect(companionState.selectedTab == .collection)
        guard case let .collectionCombatant(detail) = companionState.pendingCollectionPresentation else {
            Issue.record("Expected pending collection combatant presentation")
            return
        }
        assertCollectionDetail(
            detail,
            kind: .companion,
            combatantID: "wolf"
        )

        let itemState = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "item:shortsword-basic"])
        )

        #expect(itemState.selectedTab == .collection)
        guard case let .collectionItem(itemID) = itemState.pendingCollectionPresentation else {
            Issue.record("Expected pending collection item presentation")
            return
        }
        #expect(itemID == "shortsword-basic")
    }

    @Test(arguments: [
        "battle",
        "battle-victory",
        "shop",
        "mystery",
        "options",
    ])
    func launchScreensRouteToExpectedPlayOrOptionsState(screen: String) throws {
        var arguments = ["-launch-screen", screen]
        if screen == "shop" {
            arguments = ["-reset-state", "-seed-test-progress"] + arguments
        } else if screen == "mystery" {
            arguments = ["-reset-state"] + arguments
        }
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: arguments)
        )

        switch screen {
        case "battle":
            #expect(state.selectedTab == .play)
            let activeBattle = try #require(state.battle.activeBattle)
            #expect(activeBattle.resumeToken == .journey(stageID: "chapter-1-stage-1"))
        case "battle-victory":
            let activeBattle = try #require(state.battle.activeBattle)
            #expect(activeBattle.resumeToken == .journey(stageID: "chapter-1-stage-1"))
            #expect(state.battle.spectacle.isShowingVictory)
            #expect(state.battle.spectacle.victorySummary != nil)
            #expect(state.selectedTab == .play)
        case "shop":
            let session = try #require(state.play.encounters.activeShopEncounter)
            #expect(session.stage.id == "chapter-2-stage-8")
            #expect(!(session.offers.isEmpty))
            #expect(state.selectedTab == .play)
        case "mystery":
            let session = try #require(state.play.encounters.activeMysteryEncounter)
            #expect(session.stage.id == "chapter-1-stage-2")
            #expect(state.selectedTab == .play)
        case "options":
            #expect(state.selectedTab == .options)
        default:
            Issue.record("Unexpected launch screen \(screen)")
        }
    }

    @Test func resetStateWipesPersistedSave() throws {
        let storeURL = SaveTestSupport.makeStoreURL(directoryURL: context.directoryURL)
        do {
            var save = PlayerSave.fresh
            save.roster.gold = 99
            let firstStore = try PlayerSaveStore(
                storeURL: storeURL,
                disableCloudSync: true
            )
            try firstStore.performBatchMutation { $0 = save }
        }

        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-reset-state"])
        )

        #expect(state.playerSave.roster == .freshStart)
        #expect(state.playerSave.inventory == .freshStart)

        let reloadedStore = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true
        )
        #expect(reloadedStore.roster == .freshStart)
    }

    @Test func seedTestProgressAppliesDeterministicBaseline() throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-seed-test-progress"])
        )

        #expect(state.playerSave.roster == .testSeed)
        #expect(state.playerSave.inventory == .testSeed)
    }

    @Test(arguments: [
        (stageIDs: "chapter-1-stage-1", known: true),
        (stageIDs: "missing-stage", known: false),
    ])
    func completedStagesLaunchArgAdvancesKnownIDsAndIgnoresUnknown(
        stageIDs: String,
        known: Bool
    ) throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-completed-stages", stageIDs])
        )

        if known {
            #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-2")
            #expect(state.playerSave.journey.claimedRewardStageIDs.contains("chapter-1-stage-1"))
        } else {
            #expect(state.playerSave.journey == .initial)
        }
    }

    @Test func mapScrollTargetLaunchArgSetsSessionScrollFocus() throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-map-scroll-target", "chapter-gate-placeholder-2"])
        )
        #expect(state.play.mapScrollStageID == "chapter-gate-placeholder-2")
        #expect(state.play.mapScrollFocus?.stageID == "chapter-gate-placeholder-2")
        #expect((state.play.mapScrollFocus?.revision ?? 0) > 0)
    }

    @Test func completeStageUpdatesStoresAndMapScrollFocus() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        let stage = try #require(GameContent.chapters[0].stages.first)
        let initialGold = state.playerSave.roster.gold

        let scrollTarget = state.play.journey.completeStage(
            stage,
            hero: state.playerSave.roster.activeHero,
            companion: state.playerSave.roster.activeCompanion
        )

        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-2")
        #expect(state.playerSave.journey.completedStageIDs.contains(stage.id))
        #expect(state.playerSave.roster.gold > initialGold)
        #expect(scrollTarget == "chapter-1-stage-2")
        #expect(state.play.mapScrollStageID == "chapter-1-stage-2")
        #expect(state.play.mapScrollFocus?.stageID == "chapter-1-stage-2")
        #expect((state.play.mapScrollFocus?.revision ?? 0) > 0)
    }

    private func assertCollectionDetail(
        _ detail: CombatantDetailContext?,
        kind: CombatantDetailContext.Kind,
        combatantID: String,
        location: SourceLocation = #_sourceLocation
    ) {
        guard let detail else {
            Issue.record(
                "Expected collection detail context",
                sourceLocation: location
            )
            return
        }

        #expect(detail.kind == kind, sourceLocation: location)
        #expect(detail.combatantID == combatantID, sourceLocation: location)
    }
}
