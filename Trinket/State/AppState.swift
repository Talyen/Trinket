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
        let dependencies = AppStateBootstrap.makeDependencies(
            environment: env,
            playerSave: playerSave,
            sync: sync,
            fileStore: fileStore,
            userDefaults: userDefaults
        )

        playerSave = dependencies.playerSave
        syncCoordinator = dependencies.syncCoordinator
        musicDirector = dependencies.musicDirector
        musicPlayer = dependencies.musicPlayer
        roster = dependencies.roster
        inventory = dependencies.inventory
        homestead = dependencies.homestead
        options = dependencies.options
        battle = dependencies.battle
        journey = dependencies.journey
        sessionState = dependencies.sessionState
        initialCollectionCombatantDetail = dependencies.initialCollectionCombatantDetail
        initialCollectionItemID = dependencies.initialCollectionItemID
        selectedTab = dependencies.selectedTab

        seedJourneyProgress(completedStageIDs: env.completedStageIDs, resetState: env.resetState)
        restoreMapScroll(environment: env)
        applyLaunchScreenActions(environment: env)

        if env.launchScreen != .battle, let stageID = sessionState.activeBattleStageID {
            startRestoredBattle(stageID: stageID)
        }

        wireSyncAndBattleCallbacks()
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

        startBattle(on: stage)
    }

    private static let launchBattleStageID = "chapter-1-stage-1"

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

        startBattle(on: stage)
        selectedTab = .play
    }

    private func startBattle(on stage: Stage) {
        _ = battle.startBattle(
            stage: stage,
            hero: roster.activeHero,
            pet: roster.activePet,
            roster: roster,
            inventory: inventory
        )
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

    private func seedJourneyProgress(completedStageIDs: [String], resetState: Bool) {
        guard !completedStageIDs.isEmpty else { return }

        let stagesByID = Dictionary(
            uniqueKeysWithValues: GameContent.stages.map { ($0.id, $0) }
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
                context.apply(to: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to seed journey progress: \(error.localizedDescription, privacy: .public)"
            )
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
