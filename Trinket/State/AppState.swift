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
    let environment: AppEnvironment
    let playerSave: PlayerSaveStore
    let shellSession: PlayerShellSessionStore
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

    var activeBattleSavedAt: Date? {
        shellSession.activeBattleSavedAt
    }

    var mapScrollStageID: String? {
        get { shellSession.mapScrollStageID }
        set { shellSession.mapScrollStageID = newValue }
    }

    private(set) var mapScrollFocus: MapScrollFocus?

    var isColdLaunch = true
    var seamlessWindow: TimeInterval = 120.0
    var sameSessionWindow: TimeInterval = 3600.0
    var battleSaveExpiryWindow: TimeInterval = 172800.0

    var showResumeBattleCard: Bool {
        isSavedBattleValid()
    }

    func isSavedBattleValid() -> Bool {
        guard let stageID = shellSession.activeBattleStageID else { return false }
        guard let stage = GameContent.stage(id: stageID),
              case .battle = stage.encounter else {
            return false
        }
        guard !journey.current.hasClaimedRewards(for: stage) else {
            return false
        }
        guard let savedVersion = shellSession.activeBattleSchemaVersion,
              savedVersion == PlayerShellSessionStore.currentSchemaVersion else {
            return false
        }
        if let savedAt = shellSession.activeBattleSavedAt {
            let elapsed = Date.now.timeIntervalSince(savedAt)
            if elapsed > battleSaveExpiryWindow {
                return false
            }
        }
        return true
    }

    func resumeSavedBattle() {
        guard let stageID = shellSession.activeBattleStageID,
              let stage = GameContent.stage(id: stageID) else { return }
        startBattle(for: stage)
    }

    func abandonSavedBattle() {
        shellSession.clearBattleState()
    }

    func markCombatantAsViewed(id: String) {
        shellSession.markCombatantAsViewed(id: id)
    }

    var collectionActionableCount: Int {
        let unlockedHeroes = roster.current.unlockedHeroIDs
        let unlockedPets = roster.current.unlockedPetIDs
        let viewed = shellSession.viewedCombatantIDs
        let unviewedHeroes = unlockedHeroes.filter { !viewed.contains($0) }.count
        let unviewedPets = unlockedPets.filter { !viewed.contains($0) }.count
        return unviewedHeroes + unviewedPets
    }

    var homesteadActionableCount: Int {
        let homesteadState = homestead.current
        let rosterState = roster.current
        let definitions = GameContent.homesteadNodes
        return definitions.filter { definition in
            let status = HomesteadProjectStatus(definition: definition, homestead: homesteadState, roster: rosterState)
            return status.canBuildOrUpgrade
        }.count
    }

    var collectionBadge: Int? {
        guard selectedTab != .collection else { return nil }
        let count = collectionActionableCount
        return count > 0 ? count : nil
    }

    var homesteadBadge: String? {
        guard selectedTab != .homestead else { return nil }
        return homesteadActionableCount > 0 ? "" : nil
    }

    init(
        environment: AppEnvironment = .shared,
        playerSave: PlayerSaveStore? = nil,
        shellSessionStore: PlayerShellSessionStore? = nil,
        userDefaults: UserDefaults? = nil
    ) throws {
        self.environment = environment
        let resolvedDefaults = userDefaults ?? .standard

        let dependencies = try Self.makeBootstrapDependencies(
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
        let desiredTab = PlayerShellSessionTab(rawValue: dependencies.selectedTab.rawValue) ?? .play
        if shellSession.selectedTab != desiredTab {
            shellSession.selectedTab = desiredTab
        }
        // Only reassign if changed to avoid re-triggering didSet side effects (e.g. activeBattleSavedAt reset)
        if shellSession.activeBattleStageID != dependencies.activeBattleStageID {
            shellSession.activeBattleStageID = dependencies.activeBattleStageID
        }
        if shellSession.mapScrollStageID != dependencies.mapScrollStageID {
            shellSession.mapScrollStageID = dependencies.mapScrollStageID
        }
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
        case let .storeUnavailable(message):
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

    private var memoryPressureObserver: NotificationToken?

    func installMemoryPressureHandling() {
        #if canImport(UIKit)
        memoryPressureObserver = NotificationCenter.default.observe(
            name: UIApplication.didReceiveMemoryWarningNotification,
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

    enum AppActivityType: Equatable {
        case browsing
        case localBattle
        case serverTrackedBattle
    }

    var currentActivityType: AppActivityType {
        if battle.activeBattle != nil || shellSession.activeBattleStageID != nil {
            return .localBattle
        }
        return .browsing
    }

    func evaluateResumeRules() {
        let now = Date()
        let isCold = isColdLaunch
        isColdLaunch = false

        let elapsed = shellSession.lastBackgroundedTime.map { now.timeIntervalSince($0) } ?? .infinity

        if isCold {
            let hasLaunchOverride = environment.launchTab != nil || environment.launchScreen != nil
            if !hasLaunchOverride {
                selectedTab = .play
            }
            if !isSavedBattleValid() {
                shellSession.clearBattleState()
            }
        } else {
            switch currentActivityType {
            case .localBattle:
                if isSavedBattleValid() {
                    if elapsed < seamlessWindow {
                        if battle.activeBattle == nil, let stageID = shellSession.activeBattleStageID, let stage = GameContent.stage(id: stageID) {
                            startBattle(for: stage)
                        }
                        selectedTab = .play
                    } else {
                        if battle.activeBattle != nil {
                            let oldChange = battle.onBattleStateChange
                            battle.onBattleStateChange = nil
                            battle.activeBattle = nil
                            battle.onBattleStateChange = oldChange
                        }
                        selectedTab = .play
                    }
                } else {
                    if battle.activeBattle != nil {
                        battle.endBattle()
                    }
                    selectedTab = .play
                    shellSession.clearBattleState()
                }
            case .browsing:
                if elapsed < seamlessWindow {
                    // Resume exact tab
                } else {
                    selectedTab = .play
                    shellSession.clearBattleState()
                }
            case .serverTrackedBattle:
                break
            }
        }
    }

    private func handleScenePhaseSideEffects(_ phase: ScenePhase) {
        switch phase {
        case .background:
            musicPlayer.cancelActiveFades()
            trimMemoryFootprint()
            Task { await playerSave.flushPendingSave() }
            shellSession.lastBackgroundedTime = Date()
        case .inactive:
            musicPlayer.cancelActiveFades()
        case .active:
            evaluateResumeRules()
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
