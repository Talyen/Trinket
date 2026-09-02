import Foundation
import os
import TrinketContent
import TrinketFeatureContracts
import TrinketPersistence

extension AppState {
    public func prepareLaunchPerformanceResources() {
        sfxPlayer.warmAllCatalog(concurrentPlayerCount: 2)
    }

    struct BootstrapDependencies {
        let playerSave: PlayerSaveStore
        let shellSession: ShellSession
        let musicPlayer: MusicPlayer
        let sfxPlayer: SFXPlayer
        let options: OptionsStore
        let pendingCollectionPresentation: LaunchPresentation?
        let pendingPlayDestination: PlayLaunchDestination?
    }

    static func makeBootstrapDependencies(
        environment: AppEnvironment,
        playerSave: PlayerSaveStore?,
        userDefaults: UserDefaults,
    ) throws -> BootstrapDependencies {
        if environment.resetState {
            OptionsStore.clearDefaults(from: userDefaults)
        }

        let resolvedPlayerSave = try playerSave ?? PlayerSaveStore(
            storeName: environment.storeName,
            disableCloudSync: environment.disableCloudSync,
            resetState: environment.resetState,
            inMemoryOnly: environment.resetState && environment.storeName == nil,
            persistSaveImmediately: environment.persistSaveImmediately,
        )
        if environment.seedTestProgress {
            try resolvedPlayerSave.applyTestSeed()
        }
        if environment.skipStarterSelection,
           resolvedPlayerSave.starterSelection.phase != .complete {
            try resolvedPlayerSave.performBatchMutation { save in
                save.starterSelection = .complete
            }
        }
        if let startingGold = environment.startingGold, startingGold > 0 {
            resolvedPlayerSave.persistBatch(logging: "Failed to grant starting gold") { save in
                save.roster.grantGold(startingGold)
            }
        }

        let resolvedShellSession = ShellSession(selectedTab: selectedTab(environment: environment))

        let resolvedOptions = OptionsStore(defaults: userDefaults)
        if environment.seedTestProgress {
            resolvedOptions.ultimateCinematicShowPolicy = .never
        }

        let launchCollection = launchCollectionPresentation(for: environment.launchScreen)
        let launchPlay = launchPlayDestination(for: environment.launchScreen)

        return BootstrapDependencies(
            playerSave: resolvedPlayerSave,
            shellSession: resolvedShellSession,
            musicPlayer: MusicPlayer(isDisabled: environment.disableAudio),
            sfxPlayer: SFXPlayer(isDisabled: environment.disableAudio),
            options: resolvedOptions,
            pendingCollectionPresentation: launchCollection,
            pendingPlayDestination: launchPlay,
        )
    }

    func finishBootstrap(environment: AppEnvironment) {
        installMemoryPressureHandling()
        play.seedJourneyProgress(completedStageIDs: environment.completedStageIDs, resetState: environment.resetState)
        guard playerSave.starterSelection.phase == .complete else {
            return
        }
        switch environment.launchScreen {
        case .battle:
            play.startLaunchBattle()
        case .battleVictory:
            play.startLaunchBattle()
        case .shop:
            play.startLaunchShop()
        case .mystery:
            play.startLaunchMystery(recruitEventID: environment.mysteryRecruitEventID)
        case .heroDetail, .companionDetail, .itemDetail, .options, .labyrinth, .labyrinthMap, .none:
            break
        }
    }
}

private extension PlaySession {
    func seedJourneyProgress(completedStageIDs: [String], resetState: Bool) {
        guard !completedStageIDs.isEmpty else { return }

        let stagesByID = Dictionary(
            uniqueKeysWithValues: GameContent.stages.map { ($0.id, $0) },
        )
        let stages = completedStageIDs.compactMap { stagesByID[$0] }
        guard !stages.isEmpty else { return }

        let roster = playerSave.roster
        _ = journey.persistStageCompletions(
            stages,
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            resetJourney: resetState,
        )
    }

    func startLaunchBattle() {
        guard let stage = GameContent.stage(id: AppState.launchBattleStageID) else { return }
        _ = journey.startBattle(for: stage)
    }

    func startLaunchShop() {
        guard let stage = GameContent.stage(id: AppState.launchShopStageID) else { return }
        _ = encounters.beginShopEncounter(origin: .journey(stage: stage))
    }

    func startLaunchMystery(recruitEventID: String?) {
        guard let stage = GameContent.stage(id: AppState.launchMysteryStageID) else { return }
        _ = journey.beginMysteryEncounter(
            for: stage,
            forcedEventID: recruitEventID,
        )
    }
}

private extension AppState {
    static let launchBattleStageID = "chapter-1-stage-1"
    static let launchShopStageID = "chapter-2-stage-8"
    static let launchMysteryStageID = "chapter-1-stage-2"

    static func selectedTab(environment: AppEnvironment) -> AppTab {
        if let envTab = environment.launchTab {
            return envTab
        }
        if let launchScreen = environment.launchScreen {
            return tab(for: launchScreen)
        }
        return .play
    }

    private static func tab(for launchScreen: LaunchScreen) -> AppTab {
        switch launchScreen {
        case .heroDetail, .companionDetail, .itemDetail:
            .collection
        case .battle, .battleVictory, .shop, .mystery, .labyrinth, .labyrinthMap:
            .play
        case .options:
            .options
        }
    }

    private static func launchCollectionPresentation(
        for launchScreen: LaunchScreen?,
    ) -> LaunchPresentation? {
        switch launchScreen {
        case let .heroDetail(id):
            .collectionCombatant(CombatantDetailContext(kind: .hero, combatantID: id))
        case let .companionDetail(id):
            .collectionCombatant(CombatantDetailContext(kind: .companion, combatantID: id))
        case let .itemDetail(id):
            .collectionItem(id)
        case .battle, .battleVictory, .shop, .mystery, .options, .labyrinth, .labyrinthMap, .none:
            nil
        }
    }

    private static func launchPlayDestination(
        for launchScreen: LaunchScreen?,
    ) -> PlayLaunchDestination? {
        switch launchScreen {
        case .labyrinth, .labyrinthMap:
            .labyrinthMap
        case .battle, .battleVictory, .shop, .mystery, .options, .heroDetail, .companionDetail, .itemDetail, .none:
            nil
        }
    }
}
