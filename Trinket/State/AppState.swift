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
    var roster: PlayerRosterState {
        get { playerSave.roster }
        set { playerSave.roster = newValue }
    }

    var inventory: PlayerInventoryState {
        get { playerSave.inventory }
        set { playerSave.inventory = newValue }
    }

    var homestead: PlayerHomesteadState {
        get { playerSave.homestead }
        set { playerSave.homestead = newValue }
    }

    var collectionAttention: PlayerCollectionAttentionState {
        get { playerSave.collectionAttention }
        set { playerSave.collectionAttention = newValue }
    }

    var options: OptionsStore
    var battle: BattleSession
    var activeMysteryEncounter: MysteryEncounterSession?
    var activeShopEncounter: ShopEncounterSession?
    var journey: JourneyProgressState {
        get { playerSave.journey }
        set { playerSave.journey = newValue }
    }

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

    func markCombatantAsViewed(id: String) {
        var attention = collectionAttention.current
        attention.markCombatantAsViewed(id: id)
        collectionAttention.current = attention
    }

    func markItemAsViewed(id: String) {
        var attention = collectionAttention.current
        attention.markItemAsViewed(id: id)
        collectionAttention.current = attention
    }

    /// Starters are granted at install — they are not "new" discoveries.
    func seedStarterCombatantsAsViewedIfNeeded() {
        markCombatantAsViewed(id: PlayerRosterState.starterHeroID)
        markCombatantAsViewed(id: PlayerRosterState.starterPetID)
    }

    /// One-release import from pre-schema-7 shell session viewed IDs into `PlayerSave`.
    func migrateShellViewedCombatantsToPlayerSaveIfNeeded() {
        let shellViewed = shellSession.viewedCombatantIDs
        guard !shellViewed.isEmpty else { return }
        var attention = collectionAttention.current
        attention.viewedCombatantIDs.formUnion(shellViewed)
        collectionAttention.current = attention
        shellSession.viewedCombatantIDs = []
    }

    func showsCollectionNewMarker(for combatantID: String) -> Bool {
        let rosterState = roster.current
        let isUnlocked = rosterState.unlockedHeroIDs.contains(combatantID)
            || rosterState.unlockedPetIDs.contains(combatantID)
        guard isUnlocked else { return false }
        return !collectionAttention.current.viewedCombatantIDs.contains(combatantID)
    }

    func showsCollectionNewMarker(forItem itemID: String) -> Bool {
        guard inventory.current.items.contains(where: { $0.id == itemID }) else { return false }
        return !collectionAttention.current.viewedItemIDs.contains(itemID)
    }

    var collectionActionableCount: Int {
        let unlockedHeroes = roster.current.unlockedHeroIDs
        let unlockedPets = roster.current.unlockedPetIDs
        let viewedCombatants = collectionAttention.current.viewedCombatantIDs
        let unviewedHeroes = unlockedHeroes.filter { !viewedCombatants.contains($0) }.count
        let unviewedPets = unlockedPets.filter { !viewedCombatants.contains($0) }.count
        let viewedItems = collectionAttention.current.viewedItemIDs
        let unviewedItems = inventory.current.items.filter { !viewedItems.contains($0.id) }.count
        return unviewedHeroes + unviewedPets + unviewedItems
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
        options = dependencies.options
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
        battle.options = options
        finishBootstrap(environment: environment)
    }

    // Concurrency-Safety: isolated deinit runs on MainActor so cancelling the
    // battle tick Task does not touch MainActor-isolated state from a nonisolated deinit.
    isolated deinit {
        battleTickTask?.cancel()
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
        activeMysteryEncounter = nil
        clearSessionBattleState()
        shellSession.resetToDefaults(selectingTab: .play)
        seedStarterCombatantsAsViewedIfNeeded()
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
                        discardOrCompleteBattleBeyondSeamlessWindow()
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
}

enum ShellReconcileTrigger {
    case appeared
    case tabChanged
    case activeBattleChanged(started: Bool)
    case scenePhaseChanged
}
