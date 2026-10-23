import Testing
import TrinketBattleFeature
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

    #if DEBUG
    @Test func `unlocked development launch seeds the roster and survives access reconciliation`() async throws {
        let state = try context.makeAppState(arguments: ["-development-unlocked"], contentAccess: .free)
        #expect(state.playerSave.contentAccess.hasFullGame)
        #expect(state.fullGame.ownership.access.hasFullGame)
        #expect(state.playerSave.roster.unlockedHeroIDs.contains("wildcard"))
        #expect(state.playerSave.roster.unlockedHeroIDs.count == GameContent.heroes.count)
        #expect(state.playerSave.roster.unlockedCompanionIDs.count == GameContent.companions.count)
        await state.fullGame.start()
        state.synchronizePurchaseAccess()
        #expect(state.playerSave.contentAccess.hasFullGame)
        #expect(state.preparedContentAccess.hasFullGame)
        await state.fullGame.refreshOwnership()
        state.synchronizePurchaseAccess()
        #expect(state.playerSave.contentAccess.hasFullGame)
    }
    #endif

    @Test func `retained battle callbacks release the save and shell with AppState`() async throws {
        var battle: BattleSession?
        var state: AppState? = try AppState(
            environment: context.makeEnvironment(),
            playerSave: PlayerSaveStore(disableCloudSync: true, inMemoryOnly: true),
            userDefaults: context.userDefaults,
            makeBattleRuntime: { dependencies in
                let runtime = BattleSession(presentationEnvironment: dependencies)
                battle = runtime
                return runtime
            },
        )
        weak var save = state?.playerSave
        weak var shell = state?.shellSession
        state = nil
        for _ in 0 ..< 10 where save != nil || shell != nil {
            await Task.yield()
        }
        #expect(save == nil)
        #expect(shell == nil)
        // Keep the runtime and its real callbacks alive through the assertions.
        #expect(battle != nil)
    }

    @Test func `starter selection completes with chosen party and leaves Play at its root`() throws {
        let state = try context.makeAppState(environment: context.makeOnboardingEnvironment())

        #expect(state.confirmStarterHero("wizard").value)
        #expect(state.completeStarterSelection(companionID: "frost_whelp").value)

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

    @Test func `idle timer stays awake only for a foreground battle on Play`() throws {
        var idleTimerDisabled = true
        let browsing = try context.makeAppState()
        browsing.setIdleTimerDisabled = { idleTimerDisabled = $0 }
        browsing.reconcileShellState(.scenePhaseChanged, scenePhase: .active)
        #expect(!idleTimerDisabled)

        let playing = try context.makeAppState(arguments: ["-launch-screen", "battle"])
        try #require(playing.play.battle.activeBattle != nil)
        playing.setIdleTimerDisabled = { idleTimerDisabled = $0 }
        playing.reconcileShellState(.activeBattleChanged(started: true), scenePhase: .active)
        #expect(idleTimerDisabled)
        playing.selectedTab = .options
        playing.reconcileShellState(.selectedTabChanged, scenePhase: .active)
        #expect(!idleTimerDisabled)
        playing.selectedTab = .play
        playing.reconcileShellState(.selectedTabChanged, scenePhase: .active)
        #expect(idleTimerDisabled)
        playing.reconcileShellState(.scenePhaseChanged, scenePhase: .inactive)
        #expect(!idleTimerDisabled)
        playing.reconcileShellState(.scenePhaseChanged, scenePhase: .active)
        #expect(idleTimerDisabled)
        playing.play.battle.endBattle()
        playing.reconcileShellState(.activeBattleChanged(started: false), scenePhase: .active)
        #expect(!idleTimerDisabled)
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

    @Test func `scene phase flushes accepted recovery save synchronously`() throws {
        let storeURL = SaveTestSupport.makeStoreURL(directoryURL: context.directoryURL)
        let playerSave = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
        )
        let state = try context.makeAppState(playerSave: playerSave)
        let goldBefore = state.playerSave.roster.gold
        playerSave.forcesNextDatabaseSaveFailure = true
        try playerSave.performFixtureMutation { $0.roster.grantGold(13) }
        #expect(playerSave.isPersistenceDegraded)

        state.reconcileShellState(.scenePhaseChanged, scenePhase: .background)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        #expect(reloaded.roster.gold == goldBefore + 13)
        #expect(!playerSave.isPersistenceDegraded)
        #expect(playerSave.lastPersistenceError == nil)
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
            try firstStore.performFixtureMutation { $0 = save }
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
}
