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

        let launch = launchResolution(for: environment.launchScreen)

        return BootstrapDependencies(
            playerSave: resolvedPlayerSave,
            shellSession: resolvedShellSession,
            musicPlayer: MusicPlayer(isDisabled: environment.disableAudio),
            sfxPlayer: SFXPlayer(isDisabled: environment.disableAudio),
            options: resolvedOptions,
            pendingCollectionPresentation: launch.collection,
            pendingPlayDestination: launch.play,
        )
    }

    func finishBootstrap(environment: AppEnvironment) {
        installMemoryPressureHandling()
        play.seedJourneyProgress(completedStageIDs: environment.completedStageIDs, resetState: environment.resetState)
        guard playerSave.starterSelection.phase == .complete else {
            return
        }
        switch environment.launchScreen {
        case .battle, .battleVictory:
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
        environment.launchTab ?? launchResolution(for: environment.launchScreen).tab
    }

    private struct LaunchResolution {
        let tab: AppTab
        let collection: LaunchPresentation?
        let play: PlayLaunchDestination?
    }

    private static func launchResolution(for launchScreen: LaunchScreen?) -> LaunchResolution {
        switch launchScreen {
        case let .heroDetail(id):
            LaunchResolution(
                tab: .collection,
                collection: .collectionCombatant(CombatantDetailContext(kind: .hero, combatantID: id)),
                play: nil,
            )
        case let .companionDetail(id):
            LaunchResolution(
                tab: .collection,
                collection: .collectionCombatant(CombatantDetailContext(kind: .companion, combatantID: id)),
                play: nil,
            )
        case let .itemDetail(id):
            LaunchResolution(tab: .collection, collection: .collectionItem(id), play: nil)
        case .options:
            LaunchResolution(tab: .options, collection: nil, play: nil)
        case .labyrinth, .labyrinthMap:
            LaunchResolution(tab: .play, collection: nil, play: .labyrinthMap)
        case .battle, .battleVictory, .shop, .mystery, .none:
            LaunchResolution(tab: .play, collection: nil, play: nil)
        }
    }
}
