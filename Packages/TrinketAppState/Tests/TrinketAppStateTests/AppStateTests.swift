import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistenceTestSupport
@testable import TrinketAppState
@testable import TrinketPersistence

@MainActor
struct AppStateTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func `starter selection completes with chosen party and leaves Play at its root`() throws {
        let state = try context.makeAppState(environment: context.makeOnboardingEnvironment())

        #expect(state.confirmStarterHero("wizard"))
        #expect(state.completeStarterSelection(companionID: "frost_whelp"))

        #expect(state.playerSave.starterSelection == .complete)
        #expect(state.playerSave.roster.activeHeroID == "wizard")
        #expect(state.playerSave.roster.activeCompanionID == "frost_whelp")
        #expect(state.playerSave.roster.unlockedHeroIDs == ["wizard"])
        #expect(state.playerSave.roster.unlockedCompanionIDs == ["frost_whelp"])
        #expect(state.selectedTab == .play)
        #expect(state.play.consumePendingDestination() == nil)
    }

    @Test func `launch tab overrides default tab and survives foreground`() throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-selectedTab", "homestead"]),
        )

        #expect(state.selectedTab == .homestead)
        state.reconcileShellState(.scenePhaseChanged, scenePhase: .active)
        #expect(state.selectedTab == .homestead)

        state.selectedTab = .collection
        state.reconcileShellState(.scenePhaseChanged, scenePhase: .background)
        state.reconcileShellState(.scenePhaseChanged, scenePhase: .active)
        #expect(state.selectedTab == .collection)

        #expect(try context.makeAppState().selectedTab == .play)
    }

    @Test func `scene phase suspends and resumes battle auto end`() throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "battle"]),
        )
        #expect(state.play.battle.activeBattle != nil)
        #expect(!state.play.battle.isSuspendedForScenePhase)

        state.reconcileShellState(.scenePhaseChanged, scenePhase: .inactive)
        #expect(state.play.battle.isSuspendedForScenePhase)

        state.reconcileShellState(.scenePhaseChanged, scenePhase: .background)
        #expect(state.play.battle.isSuspendedForScenePhase)

        state.reconcileShellState(.scenePhaseChanged, scenePhase: .active)
        #expect(!state.play.battle.isSuspendedForScenePhase)
    }

    @Test func `scene phase flushes deferred player save synchronously`() throws {
        let storeURL = SaveTestSupport.makeStoreURL(directoryURL: context.directoryURL)
        let playerSave = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
        )
        let state = try context.makeAppState(playerSave: playerSave)
        let goldBefore = state.playerSave.roster.gold
        try state.playerSave.performBatchMutation({ $0.roster.grantGold(13) }, persistImmediately: false)

        state.reconcileShellState(.scenePhaseChanged, scenePhase: .background)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        #expect(reloaded.roster.gold == goldBefore + 13)
        #expect(playerSave.lastPersistenceError == nil)
    }

    @Test(arguments: [
        ("hero", "knight", CombatantDetailContext.Kind.hero),
        ("companion", "wolf", .companion),
    ])
    func `collection combatant launch screens open the requested detail`(
        screen: String, combatantID: String, kind: CombatantDetailContext.Kind,
    ) throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "\(screen):\(combatantID)"]),
        )
        #expect(state.selectedTab == .collection)
        guard case let .collectionCombatant(presentation) = state.pendingCollectionPresentation else {
            Issue.record("Expected pending collection combatant presentation")
            return
        }
        let detail = try #require(presentation)
        #expect(detail.kind == kind)
        #expect(detail.combatantID == combatantID)
    }

    @Test func `collection item launch screen opens the requested item`() throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-launch-screen", "item:shortsword-basic"]),
        )
        #expect(state.selectedTab == .collection)
        guard case let .collectionItem(itemID) = state.pendingCollectionPresentation else {
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
    func `launch screens route to expected play or options state`(screen: String) throws {
        var arguments = ["-launch-screen", screen]
        if screen == "shop" {
            arguments = ["-reset-state", "-seed-test-progress"] + arguments
        } else if screen == "mystery" {
            arguments = ["-reset-state"] + arguments
        }
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: arguments),
        )

        switch screen {
        case "battle":
            #expect(state.selectedTab == .play)
            let activeBattle = try #require(state.play.battle.activeBattle)
            #expect(activeBattle.runKey == PlayBattleOrigin.journey(stageID: "chapter-1-stage-1").runKey)
        case "battle-victory":
            let activeBattle = try #require(state.play.battle.activeBattle)
            #expect(activeBattle.runKey == PlayBattleOrigin.journey(stageID: "chapter-1-stage-1").runKey)
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

    @Test func `reset state wipes persisted save`() throws {
        let storeURL = SaveTestSupport.makeStoreURL(directoryURL: context.directoryURL)
        do {
            var save = PlayerSave.fresh
            save.roster.gold = 99
            let firstStore = try PlayerSaveStore(
                storeURL: storeURL,
                disableCloudSync: true,
            )
            try firstStore.performBatchMutation { $0 = save }
        }

        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-reset-state"]),
        )

        #expect(state.playerSave.roster == .freshStart)
        #expect(state.playerSave.inventory == .freshStart)

        let reloadedStore = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
        )
        #expect(reloadedStore.roster == .freshStart)
    }

    @Test(arguments: [
        (stageIDs: "chapter-1-stage-1", known: true),
        (stageIDs: "missing-stage", known: false),
    ])
    func `completed stages launch arg advances known I ds and ignores unknown`(
        stageIDs: String,
        known: Bool,
    ) throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-completed-stages", stageIDs]),
        )

        if known {
            #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-2")
            #expect(state.playerSave.journey.claimedRewardStageIDs.contains("chapter-1-stage-1"))
        } else {
            #expect(state.playerSave.journey == .initial)
        }
    }
}
