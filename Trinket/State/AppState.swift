import BattleEngine
import Foundation
import Observation
import os
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketPersistence
#if canImport(UIKit)
import UIKit
#endif

let appStateLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "AppState"
)

@MainActor
@Observable
final class AppState {
    private let environment: AppEnvironment
    let playerSave: PlayerSaveStore
    private let shellSession: PlayerShellSessionStore
    let musicPlayer: MusicPlayer
    var shellScenePhase: ScenePhase = .active
    var roster: PlayerRosterStore
    var inventory: PlayerInventoryStore
    var homestead: PlayerHomesteadStore
    var options: OptionsStore
    var battle: BattleSession
    var journey: PlayerJourneyStore
    private(set) var pendingCollectionPresentation: LaunchPresentation?

    var battleTickTask: Task<Void, Never>?

    var selectedTab: AppTab {
        get { AppTab(shellSessionTab: shellSession.selectedTab) ?? .play }
        set { shellSession.selectedTab = PlayerShellSessionTab(rawValue: newValue.rawValue) ?? .play }
    }

    var activeBattleStageID: String? {
        get { shellSession.activeBattleStageID }
        set { shellSession.activeBattleStageID = newValue }
    }

    var mapScrollStageID: String? {
        get { shellSession.mapScrollStageID }
        set { shellSession.mapScrollStageID = newValue }
    }

    private(set) var mapScrollFocus: MapScrollFocus?

    init(
        environment: AppEnvironment = .shared,
        playerSave: PlayerSaveStore? = nil,
        shellSessionStore: PlayerShellSessionStore? = nil,
        userDefaults: UserDefaults? = nil
    ) {
        self.environment = environment
        let resolvedDefaults = userDefaults ?? .standard

        let dependencies = Self.makeBootstrapDependencies(
            environment: environment,
            playerSave: playerSave,
            shellSessionStore: shellSessionStore,
            userDefaults: resolvedDefaults
        )

        self.playerSave = dependencies.playerSave
        shellSession = dependencies.shellSession
        musicPlayer = dependencies.musicPlayer
        roster = dependencies.roster
        inventory = dependencies.inventory
        homestead = dependencies.homestead
        options = dependencies.options
        journey = dependencies.journey
        pendingCollectionPresentation = dependencies.pendingCollectionPresentation
        shellSession.selectedTab = PlayerShellSessionTab(rawValue: dependencies.selectedTab.rawValue) ?? .play
        shellSession.activeBattleStageID = dependencies.activeBattleStageID
        shellSession.mapScrollStageID = dependencies.mapScrollStageID
        battle = BattleSession()
        finishBootstrap(environment: environment)
    }

    func consumePendingCollectionPresentation() -> LaunchPresentation? {
        defer { pendingCollectionPresentation = nil }
        return pendingCollectionPresentation
    }

    var persistenceStatusMessage: String? {
        switch playerSave.lastPersistenceError {
        case .writeFailed:
            return "Couldn't save progress to this device. Your latest changes may be lost if the app closes."
        case let .invalidSave(message):
            return message
        case .none:
            return nil
        }
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
        if let resultingJourney = persistStageCompletions(
            [stage],
            hero: hero,
            pet: pet,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards
        ) {
            scrollTarget = JourneyMapPresentation.scrollFocusID(for: resultingJourney)
            noteMapScrollFocus(scrollTarget)
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
                hero: configuration.hero.combatant,
                pet: configuration.pet.combatant,
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
        clearSessionBattleState()
        shellSession.resetToDefaults(selectingTab: .play)
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

    func clearSessionBattleState() {
        shellSession.clearBattleState()
    }

    func noteMapScrollFocus(_ targetID: String) {
        mapScrollStageID = targetID
        let nextRevision = (mapScrollFocus?.revision ?? 0) + 1
        mapScrollFocus = MapScrollFocus(stageID: targetID, revision: nextRevision)
    }

    @discardableResult
    func startBattle(for stage: Stage) -> StageMapMessage? {
        guard battle.activeBattle == nil else { return nil }

        guard let encounter = ActiveBattleConfiguration.resolvedEncounter(for: stage) else {
            return StageMapMessage(title: "Encounter Missing", message: "This stage is not ready yet.")
        }

        battle.preview = nil
        battle.activeBattle = makeActiveBattleConfiguration(
            stageID: stage.id,
            hero: roster.activeHero,
            pet: roster.activePet,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: stage.rewards
        )
        battle.isPaused = selectedTab != .play
        syncBattleTickLoop()
        return nil
    }

    func restartActiveBattle() {
        guard let activeBattle = battle.activeBattle else { return }

        let hero = roster.heroes.first(where: { $0.id == activeBattle.hero.combatant.id })
            ?? roster.activeHero
        let pet = roster.pets.first(where: { $0.id == activeBattle.pet.combatant.id })
            ?? roster.activePet

        battle.activeBattle = makeActiveBattleConfiguration(
            stageID: activeBattle.stageID,
            hero: hero,
            pet: pet,
            enemy: activeBattle.enemy,
            enemyEncounterLevel: activeBattle.enemyEncounterLevel,
            stageReward: activeBattle.stageReward
        )
        syncBattleTickLoop()
    }

    private func makeActiveBattleConfiguration(
        stageID: String?,
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        stageReward: StageReward?
    ) -> ActiveBattleConfiguration {
        ActiveBattleConfiguration.make(
            stageID: stageID,
            rngSeed: UInt64.random(in: UInt64.min ... UInt64.max),
            hero: hero,
            pet: pet,
            roster: roster,
            inventory: inventory,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward
        )
    }

    @discardableResult
    func handleStagePrimaryAction(for stage: Stage) -> StageMapMessage? {
        switch stage.encounter {
        case .battle:
            return startBattle(for: stage)
        case .event, .shop, .rest, .mysteryEvent:
            completeStage(stage, hero: roster.activeHero, pet: roster.activePet)
            return nil
        }
    }

    func reconcileShellState(_ trigger: ShellReconcileTrigger, scenePhase: ScenePhase) {
        shellScenePhase = scenePhase

        switch trigger {
        case .appeared:
            if battle.activeBattle != nil, selectedTab != .play {
                battle.isPaused = true
            }
        case .tabChanged:
            if battle.activeBattle != nil {
                // Leaving Play pauses combat; returning stays paused until the player resumes.
                battle.isPaused = true
            }
        case let .activeBattleChanged(started):
            if started {
                battle.isPaused = selectedTab != .play
            } else {
                battle.isPaused = false
                musicPlayer.clearEncounterResumePositions()
            }
        case .scenePhaseChanged:
            if scenePhase != .active, battle.activeBattle != nil {
                battle.isPaused = true
            }
            handleScenePhaseSideEffects(scenePhase)
        }

        refreshMusic(scenePhase: scenePhase)
        syncBattleTickLoop()
    }

    func installMemoryPressureHandling() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.trimMemoryFootprint()
            }
        }
        #endif
    }

    func trimMemoryFootprint() {
        battle.trimMemoryFootprint(releaseBattleLog: true)
        musicPlayer.trimMemoryFootprint()
    }

    func refreshMusic(scenePhase: ScenePhase) {
        musicPlayer.update(
            route: MusicRoute.resolve(
                selectedTab: selectedTab,
                preview: battle.preview,
                activeBattle: battle.activeBattle,
                sceneIsActive: scenePhase == .active,
                musicVolume: options.musicVolume
            ),
            volume: options.musicVolume
        )
    }

    private func handleScenePhaseSideEffects(_ phase: ScenePhase) {
        switch phase {
        case .background:
            musicPlayer.cancelActiveFades()
            trimMemoryFootprint()
            Task { await playerSave.flushPendingSave() }
        case .inactive:
            musicPlayer.cancelActiveFades()
        case .active:
            break
        @unknown default:
            break
        }
    }

    @discardableResult
    func persistStageCompletions(
        _ stages: [Stage],
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        resetJourney: Bool = false
    ) -> JourneyProgressState? {
        guard !stages.isEmpty else { return nil }

        var resultingJourney = journey.current
        do {
            try playerSave.performBatchMutation { save in
                var context = save.stageCompletionContext()
                if resetJourney {
                    context.journey = .initial
                }
                for (index, stage) in stages.enumerated() {
                    let isLast = index == stages.count - 1
                    StageCompletion.complete(
                        stage,
                        hero: hero,
                        pet: pet,
                        battleEarnedGold: isLast ? battleEarnedGold : 0,
                        materialRewards: isLast ? materialRewards : nil,
                        in: GameContent.chapters,
                        context: &context
                    )
                }
                context.apply(to: &save)
                resultingJourney = context.journey
            }
        } catch {
            appStateLogger.error(
                "Failed to persist stage completions: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
        return resultingJourney
    }
}

enum ShellReconcileTrigger {
    case appeared
    case tabChanged
    case activeBattleChanged(started: Bool)
    case scenePhaseChanged
}
