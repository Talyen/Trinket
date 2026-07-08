import Foundation
import os
import TrinketContent
import TrinketPersistence

extension AppState {
    struct BootstrapDependencies {
        let playerSave: PlayerSaveStore
        let shellSession: PlayerShellSessionStore
        let musicPlayer: MusicPlayer
        let options: OptionsStore
        let selectedTab: AppTab
        let activeBattleStageID: String?
        let mapScrollStageID: String?
        let pendingCollectionPresentation: LaunchPresentation?
    }

    static func makeBootstrapDependencies(
        environment: AppEnvironment,
        playerSave: PlayerSaveStore?,
        shellSessionStore: PlayerShellSessionStore?,
        userDefaults: UserDefaults
    ) throws -> BootstrapDependencies {
        if environment.resetState {
            clearResetStateDefaults(from: userDefaults)
        }

        let resolvedPlayerSave = try playerSave ?? PlayerSaveStore(
            storeName: environment.storeName,
            disableCloudSync: environment.disableCloudSync,
            resetState: environment.resetState,
            inMemoryOnly: environment.resetState && environment.storeName == nil,
            persistSaveImmediately: environment.persistSaveImmediately
        )
        if environment.seedTestProgress {
            do {
                try resolvedPlayerSave.applyTestSeed()
            } catch {
                appStateLogger.error(
                    "Failed to apply test seed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        let resolvedShellSession = try shellSessionStore ?? PlayerShellSessionStore(
            storeName: environment.storeName,
            resetState: environment.resetState,
            inMemoryOnly: environment.resetState && environment.storeName == nil,
            legacyUserDefaults: userDefaults
        )

        let resolvedOptions = OptionsStore(defaults: userDefaults)
        if let appearanceOverride = environment.appearanceOverride {
            resolvedOptions.appearance = appearanceOverride
        }

        let launchCollection = launchCollectionPresentation(for: environment.launchScreen)

        return BootstrapDependencies(
            playerSave: resolvedPlayerSave,
            shellSession: resolvedShellSession,
            musicPlayer: MusicPlayer(isDisabled: environment.disableAudio),
            options: resolvedOptions,
            selectedTab: selectedTab(
                environment: environment,
                restoredTab: AppTab(shellSessionTab: resolvedShellSession.selectedTab)
            ),
            activeBattleStageID: resolvedShellSession.activeBattleStageID,
            mapScrollStageID: resolvedShellSession.mapScrollStageID,
            pendingCollectionPresentation: launchCollection
        )
    }

    func finishBootstrap(environment: AppEnvironment) {
        seedJourneyProgress(completedStageIDs: environment.completedStageIDs, resetState: environment.resetState)
        if let mapScrollTarget = environment.mapScrollTarget {
            noteMapScrollFocus(mapScrollTarget)
        }
        if environment.launchScreen == .battle {
            startLaunchBattle()
        }

        battle.onBattleStateChange = { [weak self] stageID in
            self?.activeBattleStageID = stageID
            self?.syncBattleTickLoop()
        }
        installMemoryPressureHandling()
        syncBattleTickLoop()
    }

    private static func clearResetStateDefaults(from defaults: UserDefaults) {
        PlayerShellSessionStore.clearLegacyKeys(from: defaults)
        defaults.removeObject(forKey: OptionsStore.musicVolumeKey)
        defaults.removeObject(forKey: OptionsStore.effectsVolumeKey)
        defaults.removeObject(forKey: OptionsStore.hapticsEnabledKey)
        defaults.removeObject(forKey: OptionsStore.appearanceKey)
        defaults.removeObject(forKey: OptionsStore.ultimateCinematicSkipPolicyKey)
        defaults.removeObject(forKey: OptionsStore.seenUltimateCinematicsKey)
    }

    private func seedJourneyProgress(completedStageIDs: [String], resetState: Bool) {
        guard !completedStageIDs.isEmpty else { return }

        let stagesByID = Dictionary(
            uniqueKeysWithValues: GameContent.stages.map { ($0.id, $0) }
        )
        let stages = completedStageIDs.compactMap { stagesByID[$0] }
        guard !stages.isEmpty else { return }

        _ = persistStageCompletions(
            stages,
            hero: roster.activeHero,
            pet: roster.activePet,
            resetJourney: resetState
        )
    }

    private func startLaunchBattle() {
        guard let stage = GameContent.stage(id: Self.launchBattleStageID) else { return }
        _ = startBattle(for: stage)
    }

    private func startRestoredBattle(stageID: String) {
        guard let stage = GameContent.stage(id: stageID),
              case .battle = stage.encounter
        else {
            activeBattleStageID = nil
            return
        }

        guard !journey.current.hasClaimedRewards(for: stage) else {
            activeBattleStageID = nil
            return
        }

        _ = startBattle(for: stage)
        selectedTab = .play
    }

    private static let launchBattleStageID = "chapter-1-stage-1"

    private static func selectedTab(environment: AppEnvironment, restoredTab: AppTab?) -> AppTab {
        if let envTab = environment.launchTab {
            return envTab
        }
        if let launchScreen = environment.launchScreen {
            return tab(for: launchScreen)
        }
        return restoredTab ?? .play
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

    private static func launchCollectionPresentation(
        for launchScreen: LaunchScreen?
    ) -> LaunchPresentation? {
        switch launchScreen {
        case let .heroDetail(id):
            return .collectionCombatant(CombatantDetailContext(kind: .hero, combatantID: id))
        case let .petDetail(id):
            return .collectionCombatant(CombatantDetailContext(kind: .pet, combatantID: id))
        case let .itemDetail(id):
            return .collectionItem(id)
        case .battle, .options, .none:
            return nil
        }
    }
}

extension AppTab {
    init?(shellSessionTab: PlayerShellSessionTab) {
        self.init(rawValue: shellSessionTab.rawValue)
    }
}
