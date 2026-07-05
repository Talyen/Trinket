import Foundation
import Observation
import os
import TrinketContent
import TrinketPersistence

private let appStateLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "AppState"
)

@MainActor
@Observable
final class AppState {
    let playerSave: PlayerSaveStore
    let syncCoordinator: PlayerSaveSyncCoordinator
    let musicDirector: MusicDirector
    let musicPlayer: MusicPlayer
    var selectedTab: AppTab
    var roster: PlayerRosterStore
    var inventory: PlayerInventoryStore
    var homestead: PlayerHomesteadStore
    var options: OptionsStore
    var battle: BattleSession
    var journey: PlayerJourneyStore
    var lastPlayFlowError: String?
    let sessionState: SessionStateStore
    let initialCollectionCombatantDetail: CombatantCollectionDetailSelection?
    let initialCollectionItemID: String?

    init(
        environment: AppEnvironment = .shared,
        playerSave: PlayerSaveStore? = nil,
        sync: (any PlayerSaveSyncing)? = nil,
        fileStore: PlayerSaveFileStore? = nil,
        userDefaults: UserDefaults? = nil
    ) {
        let env = environment
        let resolvedDefaults = userDefaults ?? .standard
        let resolvedFileStore = fileStore ?? PlayerSaveFileStore()
        if env.resetState {
            resolvedDefaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
            resolvedFileStore.deleteSave()
        }

        let resolvedPlayerSave = playerSave ?? PlayerSaveStore(fileStore: resolvedFileStore)
        if env.seedTestProgress {
            do {
                try resolvedPlayerSave.applyTestSeed()
            } catch {
                appStateLogger.error(
                    "Failed to apply test seed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        let resolvedSync = sync ?? PlayerSaveSyncFactory.makeSyncService()
        let resolvedOptions = OptionsStore(defaults: resolvedDefaults)
        if let themeOverride = env.themeOverride {
            resolvedOptions.theme = themeOverride
        }

        let resolvedSessionState = SessionStateStore(defaults: resolvedDefaults)

        self.playerSave = resolvedPlayerSave
        syncCoordinator = PlayerSaveSyncCoordinator(sync: resolvedSync, playerSaveStore: resolvedPlayerSave)
        musicDirector = MusicDirector()
        musicPlayer = MusicPlayer(isDisabled: env.disableAudio)
        roster = PlayerRosterStore(saveStore: resolvedPlayerSave)
        inventory = PlayerInventoryStore(saveStore: resolvedPlayerSave)
        homestead = PlayerHomesteadStore(saveStore: resolvedPlayerSave)
        options = resolvedOptions
        battle = BattleSession()
        journey = PlayerJourneyStore(saveStore: resolvedPlayerSave)
        sessionState = resolvedSessionState
        initialCollectionCombatantDetail = Self.collectionCombatantDetail(for: env.launchScreen)
        initialCollectionItemID = Self.collectionItemID(for: env.launchScreen)

        // Tab precedence: collection deep links always open Collection; otherwise
        // environment arg > launch-screen default > session state > default.
        if Self.isCollectionDetailLaunch(env.launchScreen) {
            selectedTab = .collection
        } else if let envTab = env.launchTab {
            selectedTab = envTab
        } else if env.launchScreen != nil {
            selectedTab = Self.defaultTab(for: env.launchScreen)
        } else if let savedTab = sessionState.selectedTab {
            selectedTab = savedTab
        } else {
            selectedTab = .play
        }

        seedJourneyProgress(completedStageIDs: env.completedStageIDs, resetState: env.resetState)
        if let mapScrollTarget = env.mapScrollTarget {
            journey.requestMapScroll(to: mapScrollTarget)
        } else if let savedScrollTarget = sessionState.mapScrollStageID,
                  Self.shouldRestoreMapScroll(savedScrollTarget, journey: journey.current)
        {
            journey.requestMapScroll(to: savedScrollTarget)
        }

        applyLaunchScreenActions(environment: env)

        // Restore battle from session if no launch-screen battle was requested
        if env.launchScreen != .battle, let stageID = sessionState.activeBattleStageID {
            startRestoredBattle(stageID: stageID)
        }

        // Wire session state updates from battle lifecycle
        battle.onBattleStateChange = { [weak self] stageID in
            self?.sessionState.activeBattleStageID = stageID
        }
        battle.onBattleEnded = { [weak self] in
            Task { await self?.syncCoordinator.onBattleEnded() }
        }
        syncCoordinator.hasActiveBattle = { [weak self] in
            self?.battle.activeBattle != nil ?? false
        }
    }

    private func applyLaunchScreenActions(environment: AppEnvironment) {
        switch environment.launchScreen {
        case .battle:
            startLaunchBattle()
        case .heroDetail, .petDetail, .itemDetail, .options, .none:
            break
        }
    }

    private func startLaunchBattle() {
        guard let stage = GameContent.chapters
            .flatMap(\.stages)
            .first(where: { $0.id == Self.launchBattleStageID })
        else { return }

        _ = battle.startBattle(
            stage: stage,
            hero: roster.activeHero,
            pet: roster.activePet,
            roster: roster,
            inventory: inventory
        )
    }

    private static let launchBattleStageID = "chapter-1-stage-1"

    private func startRestoredBattle(stageID: String) {
        guard let stage = GameContent.chapters
            .flatMap(\.stages)
            .first(where: { $0.id == stageID }),
              case .battle = stage.encounter
        else {
            sessionState.activeBattleStageID = nil
            return
        }

        guard !journey.current.hasClaimedRewards(for: stage) else {
            sessionState.activeBattleStageID = nil
            return
        }

        _ = battle.startBattle(
            stage: stage,
            hero: roster.activeHero,
            pet: roster.activePet,
            roster: roster,
            inventory: inventory
        )
        selectedTab = .play
    }

    @discardableResult
    func resetGameplayProgress() -> Bool {
        do {
            try playerSave.resetGameplayProgress()
        } catch {
            appStateLogger.error(
                "Failed to reset gameplay progress: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
        battle.endBattle()
        sessionState.clearBattleState()
        sessionState.selectedTab = nil
        selectedTab = .play
        journey.mapScrollRequest = nil
        Task {
            await syncCoordinator.uploadImmediately(playerSave.currentSave)
        }
        return true
    }

    private static func isCollectionDetailLaunch(_ launchScreen: LaunchScreen?) -> Bool {
        switch launchScreen {
        case .heroDetail, .petDetail, .itemDetail:
            true
        case .battle, .options, .none:
            false
        }
    }

    private func seedJourneyProgress(completedStageIDs: [String], resetState: Bool) {
        guard !completedStageIDs.isEmpty else { return }

        let stagesByID = Dictionary(
            uniqueKeysWithValues: GameContent.chapters.flatMap(\.stages).map { ($0.id, $0) }
        )
        let stages = completedStageIDs.compactMap { stagesByID[$0] }
        guard !stages.isEmpty else { return }

        var context = StageCompletionContext(
            roster: roster.current,
            inventory: inventory.current,
            homestead: homestead.current,
            journey: resetState ? .initial : journey.current
        )

        for stage in stages {
            StageCompletion.claimRewardsIfNeeded(
                for: stage,
                hero: roster.activeHero,
                pet: roster.activePet,
                context: &context
            )
            if !context.journey.isCompleted(stage) {
                context.journey.complete(stage, in: GameContent.chapters)
            }
        }

        do {
            try playerSave.performBatchMutation { save in
                save.roster = SavedRosterState(context.roster)
                save.inventory = SavedInventoryState(context.inventory)
                save.homestead = SavedHomesteadState(context.homestead)
                save.journey = context.journey
            }
        } catch {
            appStateLogger.error(
                "Failed to seed journey progress: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private static func defaultTab(for launchScreen: LaunchScreen?) -> AppTab {
        switch launchScreen {
        case .heroDetail, .petDetail, .itemDetail:
            return .collection
        case .battle:
            return .play
        case .options:
            return .options
        case .none:
            return .play
        }
    }

    private static func collectionCombatantDetail(
        for launchScreen: LaunchScreen?
    ) -> CombatantCollectionDetailSelection? {
        switch launchScreen {
        case let .heroDetail(id):
            CombatantCollectionDetailSelection(kind: .hero, combatantID: id)
        case let .petDetail(id):
            CombatantCollectionDetailSelection(kind: .pet, combatantID: id)
        case .itemDetail, .battle, .options, .none:
            nil
        }
    }

    private static func collectionItemID(for launchScreen: LaunchScreen?) -> String? {
        switch launchScreen {
        case let .itemDetail(id):
            id
        case .heroDetail, .petDetail, .battle, .options, .none:
            nil
        }
    }

    static func shouldRestoreMapScroll(
        _ targetID: String,
        journey: JourneyProgressState,
        chapters: [Chapter] = GameContent.chapters
    ) -> Bool {
        if targetID.hasPrefix("chapter-gate-") {
            return true
        }
        guard let stage = chapters.flatMap(\.stages).first(where: { $0.id == targetID }) else {
            return false
        }
        return journey.isActive(stage)
    }
}
