import Foundation
import os
import TrinketContent
import TrinketPersistence

extension AppState {
    static func makeBootstrapDependencies(
        environment: AppEnvironment,
        playerSave: PlayerSaveStore?,
        userDefaults: UserDefaults
    ) -> (
        playerSave: PlayerSaveStore,
        musicPlayer: MusicPlayer,
        roster: PlayerRosterStore,
        inventory: PlayerInventoryStore,
        homestead: PlayerHomesteadStore,
        options: OptionsStore,
        journey: PlayerJourneyStore,
        selectedTab: AppTab,
        activeBattleStageID: String?,
        mapScrollStageID: String?,
        initialCollectionCombatantDetail: CombatantDetailContext?,
        initialCollectionItemID: String?
    ) {
        if environment.resetState {
            userDefaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        }

        let resolvedPlayerSave = playerSave ?? PlayerSaveStore(
            storeName: environment.storeName,
            disableCloudSync: environment.disableCloudSync,
            resetState: environment.resetState,
            inMemoryOnly: environment.resetState && environment.storeName == nil
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

        let resolvedOptions = OptionsStore(defaults: userDefaults)
        if let appearanceOverride = environment.appearanceOverride {
            resolvedOptions.appearance = appearanceOverride
        }

        let resolvedRoster = PlayerRosterStore(saveStore: resolvedPlayerSave)
        let resolvedInventory = PlayerInventoryStore(saveStore: resolvedPlayerSave)
        let resolvedHomestead = PlayerHomesteadStore(saveStore: resolvedPlayerSave)
        let resolvedJourney = PlayerJourneyStore(saveStore: resolvedPlayerSave)
        let launchCollection = launchCollectionTargets(for: environment.launchScreen)
        let session = restoredSessionState(from: userDefaults)

        return (
            playerSave: resolvedPlayerSave,
            musicPlayer: MusicPlayer(isDisabled: environment.disableAudio),
            roster: resolvedRoster,
            inventory: resolvedInventory,
            homestead: resolvedHomestead,
            options: resolvedOptions,
            journey: resolvedJourney,
            selectedTab: selectedTab(environment: environment, restoredTab: session.tab),
            activeBattleStageID: session.activeBattleStageID,
            mapScrollStageID: session.mapScrollStageID,
            initialCollectionCombatantDetail: launchCollection.combatantDetail,
            initialCollectionItemID: launchCollection.itemID
        )
    }

    func finishBootstrap(environment: AppEnvironment) {
        seedJourneyProgress(completedStageIDs: environment.completedStageIDs, resetState: environment.resetState)
        if let mapScrollTarget = environment.mapScrollTarget {
            noteMapScrollFocus(mapScrollTarget, bumpEvenWhenUnchanged: true)
        }
        if environment.launchScreen == .battle {
            startLaunchBattle()
        } else if let stageID = activeBattleStageID {
            startRestoredBattle(stageID: stageID)
        }

        battle.onBattleStateChange = { [weak self] stageID in
            self?.activeBattleStageID = stageID
            self?.syncBattleTickLoop()
        }
        installMemoryPressureHandling()
        syncBattleTickLoop()
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

    private static func restoredSessionState(
        from defaults: UserDefaults
    ) -> (tab: AppTab?, activeBattleStageID: String?, mapScrollStageID: String?) {
        (
            restoredTab(from: defaults),
            defaults.string(forKey: activeBattleStageIDKey),
            defaults.string(forKey: mapScrollStageIDKey)
        )
    }

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
}
