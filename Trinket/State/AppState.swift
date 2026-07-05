import Foundation
import Observation
import os
import SwiftUI
import TrinketContent
import TrinketCore
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
    let initialCollectionCombatantDetail: CombatantDetailContext?
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

        let launchTargets = AppLaunchBootstrap.launchTargets(
            environment: env,
            sessionState: resolvedSessionState
        )

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
        initialCollectionCombatantDetail = launchTargets.initialCombatantDetail
        initialCollectionItemID = launchTargets.initialItemID
        selectedTab = launchTargets.selectedTab

        seedJourneyProgress(completedStageIDs: env.completedStageIDs, resetState: env.resetState)
        restoreMapScroll(environment: env)

        if launchTargets.shouldStartLaunchBattle {
            startLaunchBattle()
        } else if let stageID = launchTargets.restoredBattleStageID {
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
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil
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
                    materialRewards: materialRewards,
                    in: GameContent.chapters,
                    context: &context
                )
                context.apply(to: &save)
                scrollTarget = JourneyMapPresentation.scrollFocusID(for: context.journey)
            }
            lastPlayFlowError = nil
            sessionState.noteMapScrollFocus(scrollTarget)
        } catch {
            appStateLogger.error(
                "Failed to persist stage completion: \(error.localizedDescription, privacy: .public)"
            )
            lastPlayFlowError = "Progress couldn't be saved. Try again."
        }
        return scrollTarget
    }

    func completeActiveBattle(
        _ configuration: ActiveBattleConfiguration,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]? = nil
    ) {
        guard battle.activeBattle != nil else { return }

        if let stageID = configuration.stageID,
           let stage = GameContent.stage(id: stageID) {
            completeStage(
                stage,
                hero: configuration.hero,
                pet: configuration.pet,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards
            )
        } else if battleEarnedGold > 0 {
            grantBattleEarnedGold(battleEarnedGold)
        }
        battle.endBattle()
    }

    func grantBattleEarnedGold(_ amount: Int) {
        guard amount > 0 else { return }
        do {
            try playerSave.performBatchMutation { save in
                save.roster.gold += amount
            }
        } catch {
            appStateLogger.error(
                "Failed to persist battle gold: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func handleBattlePeriodicTick(
        configuration: ActiveBattleConfiguration,
        at date: Date
    ) {
        if let earnedGold = battle.advanceAutoTick(
            at: date,
            journey: journey.current,
            homestead: homestead.current
        ) {
            grantBattleEarnedGold(earnedGold)
            completeActiveBattle(configuration, battleEarnedGold: 0)
        }
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
            sessionState.noteMapScrollFocus(mapScrollTarget, bumpEvenWhenUnchanged: true)
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

    private func startLaunchBattle() {
        guard let stage = GameContent.stage(id: Self.launchBattleStageID) else { return }
        _ = startBattleForStage(stage)
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

        _ = startBattleForStage(stage)
        selectedTab = .play
    }

    @discardableResult
    private func startBattleForStage(_ stage: Stage) -> StageMapMessage? {
        battle.startBattle(
            stage: stage,
            hero: roster.activeHero,
            pet: roster.activePet,
            roster: roster,
            inventory: inventory
        )
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

    func updateShell(event: AppShellEvent, scenePhase: ScenePhase) {
        switch event {
        case .appeared:
            if battle.activeBattle != nil, selectedTab != .play {
                battle.isPaused = true
            }
        case let .selectedTabChanged(newTab):
            sessionState.selectedTab = newTab
            if battle.activeBattle != nil {
                // Leaving Play pauses combat; returning stays paused until the player resumes.
                battle.isPaused = true
            }
        case .activeBattleStarted:
            battle.isPaused = selectedTab != .play
        case .activeBattleEnded:
            battle.isPaused = false
            musicPlayer.clearEncounterResumePositions()
        case let .scenePhaseChanged(newPhase):
            if newPhase != .active, battle.activeBattle != nil {
                battle.isPaused = true
            }
            handleScenePhaseSideEffects(newPhase)
            refreshMusic(scenePhase: newPhase)
            return
        case .musicInputsChanged:
            break
        }

        refreshMusic(scenePhase: scenePhase)
    }

    private func handleScenePhaseSideEffects(_ phase: ScenePhase) {
        if phase == .inactive || phase == .background {
            playerSave.flushPendingPersistIfNeeded()
        }
        if phase == .background {
            Task {
                await syncCoordinator.checkpointUploadIfNeeded()
            }
        } else if phase == .active {
            Task {
                await syncCoordinator.reconcileForegroundIfSafe()
            }
        }
    }

    func refreshMusic(scenePhase: ScenePhase) {
        musicPlayer.update(
            route: MusicPlayer.route(
                selectedTab: selectedTab,
                preview: battle.preview,
                activeBattle: battle.activeBattle,
                sceneIsActive: scenePhase == .active,
                musicVolume: options.musicVolume
            ),
            volume: options.musicVolume
        )
    }
}
