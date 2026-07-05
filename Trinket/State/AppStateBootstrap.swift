import Foundation
import os
import TrinketContent
import TrinketPersistence

enum AppStateBootstrap {
    struct Dependencies {
        let playerSave: PlayerSaveStore
        let syncCoordinator: PlayerSaveSyncCoordinator
        let musicDirector: MusicDirector
        let musicPlayer: MusicPlayer
        let roster: PlayerRosterStore
        let inventory: PlayerInventoryStore
        let homestead: PlayerHomesteadStore
        let options: OptionsStore
        let battle: BattleSession
        let journey: PlayerJourneyStore
        let sessionState: SessionStateStore
        let initialCollectionCombatantDetail: CombatantCollectionDetailSelection?
        let initialCollectionItemID: String?
        let selectedTab: AppTab
    }

    private static let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "AppState"
    )

    static func makeDependencies(
        environment: AppEnvironment,
        playerSave: PlayerSaveStore?,
        sync: (any PlayerSaveSyncing)?,
        fileStore: PlayerSaveFileStore?,
        userDefaults: UserDefaults?
    ) -> Dependencies {
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
                logger.error(
                    "Failed to apply test seed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        let resolvedSync = sync ?? PlayerSaveSyncFactory.makeSyncService(
            configuration: PlayerSaveSyncConfiguration(
                disableCloudSync: environment.disableCloudSync,
                resetState: environment.resetState
            )
        )
        let resolvedOptions = OptionsStore(defaults: resolvedDefaults)
        if let appearanceOverride = environment.appearanceOverride {
            resolvedOptions.appearance = appearanceOverride
        }

        let resolvedSessionState = SessionStateStore(defaults: resolvedDefaults)
        let roster = PlayerRosterStore(saveStore: resolvedPlayerSave)
        let inventory = PlayerInventoryStore(saveStore: resolvedPlayerSave)
        let homestead = PlayerHomesteadStore(saveStore: resolvedPlayerSave)
        let journey = PlayerJourneyStore(saveStore: resolvedPlayerSave)

        return Dependencies(
            playerSave: resolvedPlayerSave,
            syncCoordinator: PlayerSaveSyncCoordinator(
                sync: resolvedSync,
                playerSaveStore: resolvedPlayerSave
            ),
            musicDirector: MusicDirector(),
            musicPlayer: MusicPlayer(isDisabled: environment.disableAudio),
            roster: roster,
            inventory: inventory,
            homestead: homestead,
            options: resolvedOptions,
            battle: BattleSession(),
            journey: journey,
            sessionState: resolvedSessionState,
            initialCollectionCombatantDetail: collectionCombatantDetail(for: environment.launchScreen),
            initialCollectionItemID: collectionItemID(for: environment.launchScreen),
            selectedTab: selectedTab(
                environment: environment,
                sessionState: resolvedSessionState
            )
        )
    }

    private static func selectedTab(
        environment: AppEnvironment,
        sessionState: SessionStateStore
    ) -> AppTab {
        if isCollectionDetailLaunch(environment.launchScreen) {
            return .collection
        }
        if let envTab = environment.launchTab {
            return envTab
        }
        if environment.launchScreen != nil {
            return defaultTab(for: environment.launchScreen)
        }
        if let savedTab = sessionState.selectedTab {
            return savedTab
        }
        return .play
    }

    private static func isCollectionDetailLaunch(_ launchScreen: LaunchScreen?) -> Bool {
        switch launchScreen {
        case .heroDetail, .petDetail, .itemDetail:
            true
        case .battle, .options, .none:
            false
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
}
