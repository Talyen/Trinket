import Foundation
import os
import TrinketContent
import TrinketPersistence

extension AppState {
    struct BootstrapDependencies {
        let playerSave: PlayerSaveStore
        let syncCoordinator: PlayerSaveSyncCoordinator
        let musicPlayer: MusicPlayer
        let roster: PlayerRosterStore
        let inventory: PlayerInventoryStore
        let homestead: PlayerHomesteadStore
        let options: OptionsStore
        let journey: PlayerJourneyStore
        let sessionState: SessionStateStore
        let selectedTab: AppTab
        let initialCollectionCombatantDetail: CombatantDetailContext?
        let initialCollectionItemID: String?
    }

    static func makeBootstrapDependencies(
        environment: AppEnvironment,
        playerSave: PlayerSaveStore?,
        sync: (any PlayerSaveSyncing)?,
        fileStore: PlayerSaveFileStore?,
        userDefaults: UserDefaults?
    ) -> BootstrapDependencies {
        let resolvedDefaults = userDefaults ?? .standard
        let resolvedFileStore = fileStore ?? PlayerSaveFileStore()
        if environment.resetState {
            resolvedDefaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
            resolvedFileStore.deleteSave()
        }

        let resolvedPlayerSave = playerSave ?? PlayerSaveStore(fileStore: resolvedFileStore)
        if environment.seedTestProgress {
            do {
                try resolvedPlayerSave.applyTestSeed()
            } catch {
                appStateLogger.error(
                    "Failed to apply test seed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        let resolvedSync = sync ?? PlayerSaveSyncConfiguration(
            disableCloudSync: environment.disableCloudSync,
            resetState: environment.resetState
        ).makeSyncService()
        let resolvedOptions = OptionsStore(defaults: resolvedDefaults)
        if let appearanceOverride = environment.appearanceOverride {
            resolvedOptions.appearance = appearanceOverride
        }

        let resolvedSessionState = SessionStateStore(defaults: resolvedDefaults)
        let resolvedRoster = PlayerRosterStore(saveStore: resolvedPlayerSave)
        let resolvedInventory = PlayerInventoryStore(saveStore: resolvedPlayerSave)
        let resolvedHomestead = PlayerHomesteadStore(saveStore: resolvedPlayerSave)
        let resolvedJourney = PlayerJourneyStore(saveStore: resolvedPlayerSave)
        let launchCollection = launchCollectionTargets(for: environment.launchScreen)

        return BootstrapDependencies(
            playerSave: resolvedPlayerSave,
            syncCoordinator: PlayerSaveSyncCoordinator(
                sync: resolvedSync,
                playerSaveStore: resolvedPlayerSave
            ),
            musicPlayer: MusicPlayer(isDisabled: environment.disableAudio),
            roster: resolvedRoster,
            inventory: resolvedInventory,
            homestead: resolvedHomestead,
            options: resolvedOptions,
            journey: resolvedJourney,
            sessionState: resolvedSessionState,
            selectedTab: selectedTab(environment: environment, sessionState: resolvedSessionState),
            initialCollectionCombatantDetail: launchCollection.combatantDetail,
            initialCollectionItemID: launchCollection.itemID
        )
    }

    func wireSyncAndBattleCallbacks() {
        battle.onBattleStateChange = { [weak self] stageID in
            self?.sessionState.activeBattleStageID = stageID
        }
        battle.onBattleEnded = { [weak self] in
            Task { await self?.syncCoordinator.onBattleEnded() }
        }
        syncCoordinator.hasActiveBattle = { [weak self] in
            guard let self else { return false }
            return self.battle.activeBattle != nil
        }
        syncCoordinator.onSessionSuperseded = { [weak self] in
            guard let self else { return }
            battle.endBattle()
            sessionState.activeBattleStageID = nil
        }
    }

    func restoreLaunchBattle(environment: AppEnvironment) {
        if environment.launchScreen == .battle {
            startLaunchBattle()
        } else if let stageID = sessionState.activeBattleStageID {
            startRestoredBattle(stageID: stageID)
        }
    }

    func seedJourneyProgress(completedStageIDs: [String], resetState: Bool) {
        guard !completedStageIDs.isEmpty else { return }

        let stagesByID = Dictionary(
            uniqueKeysWithValues: GameContent.stages.map { ($0.id, $0) }
        )
        let stages = completedStageIDs.compactMap { stagesByID[$0] }
        guard !stages.isEmpty else { return }

        let hero = roster.activeHero
        let pet = roster.activePet

        do {
            try playerSave.performBatchMutation { save in
                var context = save.stageCompletionContext()
                if resetState {
                    context.journey = .initial
                }
                for stage in stages {
                    StageCompletion.complete(
                        stage,
                        hero: hero,
                        pet: pet,
                        in: GameContent.chapters,
                        context: &context
                    )
                }
                context.apply(to: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to seed journey progress: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func restoreMapScroll(environment: AppEnvironment) {
        if let mapScrollTarget = environment.mapScrollTarget {
            sessionState.noteMapScrollFocus(mapScrollTarget, bumpEvenWhenUnchanged: true)
        }
    }

    private func startLaunchBattle() {
        guard let stage = GameContent.stage(id: Self.launchBattleStageID) else { return }
        _ = startBattle(for: stage)
    }

    private func startRestoredBattle(stageID: String) {
        guard let stage = GameContent.stage(id: stageID),
              case .battle = stage.encounter
        else {
            sessionState.activeBattleStageID = nil
            return
        }

        guard !journey.current.hasClaimedRewards(for: stage) else {
            sessionState.activeBattleStageID = nil
            return
        }

        _ = startBattle(for: stage)
        selectedTab = .play
    }

    private static let launchBattleStageID = "chapter-1-stage-1"

    private static func selectedTab(
        environment: AppEnvironment,
        sessionState: SessionStateStore
    ) -> AppTab {
        if let envTab = environment.launchTab {
            return envTab
        }
        if let launchScreen = environment.launchScreen {
            return tab(for: launchScreen)
        }
        return sessionState.selectedTab ?? .play
    }

    private static func tab(for launchScreen: LaunchScreen) -> AppTab {
        switch launchScreen {
        case .heroDetail, .petDetail, .itemDetail:
            return .collection
        case .battle:
            return .play
        case .options:
            return .options
        }
    }

    private static func launchCollectionTargets(
        for launchScreen: LaunchScreen?
    ) -> (combatantDetail: CombatantDetailContext?, itemID: String?) {
        switch launchScreen {
        case let .heroDetail(id):
            (CombatantDetailContext(kind: .hero, combatantID: id), nil)
        case let .petDetail(id):
            (CombatantDetailContext(kind: .pet, combatantID: id), nil)
        case let .itemDetail(id):
            (nil, id)
        case .battle, .options, .none:
            (nil, nil)
        }
    }

    func finishBootstrap(environment: AppEnvironment) {
        seedJourneyProgress(completedStageIDs: environment.completedStageIDs, resetState: environment.resetState)
        restoreMapScroll(environment: environment)
        restoreLaunchBattle(environment: environment)
        wireSyncAndBattleCallbacks()
    }
}