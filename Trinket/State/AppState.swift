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
    private static let launchBattleStageID = "chapter-1-stage-1"

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

        let resolvedSync = sync ?? PlayerSaveSyncConfiguration(
            disableCloudSync: env.disableCloudSync,
            resetState: env.resetState
        ).makeSyncService()
        let resolvedOptions = OptionsStore(defaults: resolvedDefaults)
        if let appearanceOverride = env.appearanceOverride {
            resolvedOptions.appearance = appearanceOverride
        }

        let resolvedSessionState = SessionStateStore(defaults: resolvedDefaults)
        let resolvedRoster = PlayerRosterStore(saveStore: resolvedPlayerSave)
        let resolvedInventory = PlayerInventoryStore(saveStore: resolvedPlayerSave)
        let resolvedHomestead = PlayerHomesteadStore(saveStore: resolvedPlayerSave)
        let resolvedJourney = PlayerJourneyStore(saveStore: resolvedPlayerSave)

        self.playerSave = resolvedPlayerSave
        syncCoordinator = PlayerSaveSyncCoordinator(
            sync: resolvedSync,
            playerSaveStore: resolvedPlayerSave
        )
        musicPlayer = MusicPlayer(isDisabled: env.disableAudio)
        roster = resolvedRoster
        inventory = resolvedInventory
        homestead = resolvedHomestead
        options = resolvedOptions
        battle = BattleSession()
        journey = resolvedJourney
        sessionState = resolvedSessionState
        initialCollectionCombatantDetail = Self.collectionCombatantDetail(for: env.launchScreen)
        initialCollectionItemID = Self.collectionItemID(for: env.launchScreen)
        selectedTab = Self.selectedTab(environment: env, sessionState: resolvedSessionState)

        seedJourneyProgress(completedStageIDs: env.completedStageIDs, resetState: env.resetState)
        restoreMapScroll(environment: env)
        applyLaunchScreenActions(environment: env)

        if env.launchScreen != .battle, let stageID = sessionState.activeBattleStageID {
            startRestoredBattle(stageID: stageID)
        }

        wireSyncAndBattleCallbacks()
    }

    var playChapter: Chapter {
        GameContent.chapter(id: journey.current.activeChapterID) ?? GameContent.chapters[0]
    }

    @discardableResult
    func completeStage(
        _ stage: Stage,
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0
    ) -> String {
        var scrollTarget = JourneyMapPresentation.scrollFocusID(for: journey.current)
        do {
            try playerSave.performBatchMutation { save in
                var context = save.stageCompletionContext()
                StageCompletion.complete(
                    stage,
                    hero: hero,
                    pet: pet,
                    battleEarnedGold: battleEarnedGold,
                    in: GameContent.chapters,
                    context: &context
                )
                context.apply(to: &save)
                scrollTarget = JourneyMapPresentation.scrollFocusID(for: context.journey)
            }
            lastPlayFlowError = nil
            sessionState.mapScrollStageID = scrollTarget
            journey.requestMapScroll(to: scrollTarget)
        } catch {
            appStateLogger.error(
                "Failed to persist stage completion: \(error.localizedDescription, privacy: .public)"
            )
            lastPlayFlowError = "Progress couldn't be saved. Try again."
        }
        return scrollTarget
    }

    func completeActiveBattle(_ configuration: ActiveBattleConfiguration, battleEarnedGold: Int) {
        guard battle.activeBattle != nil else { return }

        if let stageID = configuration.stageID,
           let stage = GameContent.stage(id: stageID) {
            completeStage(
                stage,
                hero: configuration.hero,
                pet: configuration.pet,
                battleEarnedGold: battleEarnedGold
            )
        } else if battleEarnedGold > 0 {
            var updatedRoster = roster.current
            updatedRoster.grantGold(battleEarnedGold)
            roster.current = updatedRoster
        }
        battle.endBattle()
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
            await syncCoordinator.checkpointUploadIfNeeded()
        }
        return true
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

    private func restoreMapScroll(environment: AppEnvironment) {
        if let mapScrollTarget = environment.mapScrollTarget {
            journey.requestMapScroll(to: mapScrollTarget)
        } else if let savedScrollTarget = sessionState.mapScrollStageID,
                  Self.shouldRestoreMapScroll(savedScrollTarget, journey: journey.current) {
            journey.requestMapScroll(to: savedScrollTarget)
        }
    }

    private func wireSyncAndBattleCallbacks() {
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
        guard let stage = GameContent.stage(id: Self.launchBattleStageID) else { return }

        _ = battle.startBattle(
            stage: stage,
            hero: roster.activeHero,
            pet: roster.activePet,
            roster: roster,
            inventory: inventory
        )
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

        _ = battle.startBattle(
            stage: stage,
            hero: roster.activeHero,
            pet: roster.activePet,
            roster: roster,
            inventory: inventory
        )
        selectedTab = .play
    }

    private func seedJourneyProgress(completedStageIDs: [String], resetState: Bool) {
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
