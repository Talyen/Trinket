import SwiftUI

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
        let resolvedFileStore = fileStore ?? PlayerSaveFileStore()
        if env.resetState {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
            resolvedFileStore.deleteSave()
        }

        let resolvedPlayerSave = playerSave ?? PlayerSaveStore(fileStore: resolvedFileStore)
        if env.seedTestProgress {
            resolvedPlayerSave.applyTestSeed()
        }

        let resolvedSync = sync ?? PlayerSaveSyncFactory.makeSyncService()
        let resolvedOptions = OptionsStore(defaults: userDefaults ?? .standard)
        if let themeOverride = env.themeOverride {
            resolvedOptions.theme = themeOverride
        }

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
        initialCollectionCombatantDetail = Self.collectionCombatantDetail(for: env.launchScreen)
        initialCollectionItemID = Self.collectionItemID(for: env.launchScreen)
        selectedTab = env.launchTab ?? Self.defaultTab(for: env.launchScreen)
        seedJourneyProgress(completedStageIDs: env.completedStageIDs)
        applyLaunchScreenActions(environment: env)
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

    func resetGameplayProgress() {
        playerSave.resetGameplayProgress()
    }

    private func seedJourneyProgress(completedStageIDs: [String]) {
        guard !completedStageIDs.isEmpty else { return }
        journey.current = .initial

        let stagesByID = Dictionary(
            uniqueKeysWithValues: GameContent.chapters.flatMap(\.stages).map { ($0.id, $0) }
        )
        completedStageIDs.compactMap { stagesByID[$0] }.forEach { stage in
            journey.complete(stage, in: GameContent.chapters)
            journey.markRewardsClaimed(for: stage)
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
