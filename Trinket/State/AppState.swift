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
    let sfxPlayer: SFXPlayer
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

    var aspects: PlayerAspectsState {
        get { playerSave.aspects }
        set { playerSave.aspects = newValue }
    }

    var labyrinth: PlayerLabyrinthState {
        get { playerSave.labyrinth }
        set { playerSave.labyrinth = newValue }
    }

    var options: OptionsStore
    var battle: BattleSession
    var activeMysteryEncounter: MysteryEncounterSession?
    var activeShopEncounter: ShopEncounterSession?
    var activeLabyrinthRest: LabyrinthRestSession?
    var activeLabyrinthCraft: LabyrinthCraftSession?
    var journey: JourneyProgressState {
        get { playerSave.journey }
        set { playerSave.journey = newValue }
    }

    private(set) var pendingCollectionPresentation: LaunchPresentation?
    private(set) var pendingPlayDestination: PlayLaunchDestination?

    var selectedTab: AppTab {
        get { AppTab(shellSessionTab: shellSession.selectedTab) ?? .play }
        set { shellSession.selectedTab = PlayerShellSessionTab(rawValue: newValue.rawValue) ?? .play }
    }

    var mapScrollStageID: String? {
        get { shellSession.mapScrollStageID }
        set { shellSession.mapScrollStageID = newValue }
    }

    var lastPlayMode: PlayerShellSessionPlayMode {
        get { shellSession.lastPlayMode }
        set { shellSession.lastPlayMode = newValue }
    }

    private(set) var mapScrollFocus: MapScrollFocus?

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
        sfxPlayer = dependencies.sfxPlayer
        options = dependencies.options
        pendingCollectionPresentation = dependencies.pendingCollectionPresentation
        pendingPlayDestination = dependencies.pendingPlayDestination

        let desiredTab = PlayerShellSessionTab(rawValue: dependencies.selectedTab.rawValue) ?? .play
        if shellSession.selectedTab != desiredTab {
            shellSession.selectedTab = desiredTab
        }
        if shellSession.mapScrollStageID != dependencies.mapScrollStageID {
            shellSession.mapScrollStageID = dependencies.mapScrollStageID
        }
        battle = BattleSession()
        battle.options = options
        battle.sfxPlayer = sfxPlayer
        finishBootstrap(environment: environment)
    }

    func consumePendingCollectionPresentation() -> LaunchPresentation? {
        defer { pendingCollectionPresentation = nil }
        return pendingCollectionPresentation
    }

    func consumePendingPlayDestination() -> PlayLaunchDestination? {
        defer { pendingPlayDestination = nil }
        return pendingPlayDestination
    }

    /// Queues a Play-tab deep link so mode navigation can be restored after battle ends.
    func queueReturnToBattleOrigin(from token: ActiveBattleResumeToken?) {
        pendingPlayDestination = PlayLaunchDestination.returning(from: token)
    }

    /// Ends the active battle and restores the Play mode that started it (Campaign,
    /// Aspects climb, Labyrinth map, …). Switches to the Play tab.
    func endBattleReturningToOrigin() {
        queueReturnToBattleOrigin(from: battle.activeBattle?.resumeToken)
        selectedTab = .play
        battle.endBattle()
    }

    func presentCombatLog() {
        battle.presentBattleLog()
    }

    func rememberPlayMode(_ mode: PlayerShellSessionPlayMode) {
        lastPlayMode = mode
    }

    var persistenceStatusMessage: String? {
        switch playerSave.lastPersistenceError {
        case .writeFailed:
            "Couldn't save progress to this device. Your latest changes may be lost if the app closes."
        case let .invalidSave(message):
            message
        case let .storeUnavailable(message):
            message
        case .none:
            nil
        }
    }

    /// True when save storage is degraded or was recovered by wiping a corrupt store.
    var requiresPersistenceRecoveryAcknowledgement: Bool {
        playerSave.isPersistenceDegraded || playerSave.recoveredAfterStoreDeletion
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
        activeShopEncounter = nil
        activeLabyrinthRest = nil
        activeLabyrinthCraft = nil
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

    func noteMapScrollFocus(_ targetID: String) {
        mapScrollStageID = targetID
        let nextRevision = (mapScrollFocus?.revision ?? 0) + 1
        mapScrollFocus = MapScrollFocus(stageID: targetID, revision: nextRevision)
    }

    func reconcileShellState(_ trigger: ShellReconcileTrigger, scenePhase: ScenePhase) {
        shellScenePhase = scenePhase

        switch trigger {
        case .appeared:
            break
        case .tabChanged:
            break
        case let .activeBattleChanged(started):
            if !started {
                musicPlayer.clearEncounterResumePositions()
            }
        case .scenePhaseChanged:
            handleScenePhaseSideEffects(scenePhase)
        }

        refreshMusic(scenePhase: scenePhase)
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
        sfxPlayer.stopAll()
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

    /// Always land on Play unless a UI-test launch override selected another tab/screen.
    func evaluateLaunchLanding() {
        let hasLaunchOverride = environment.launchTab != nil || environment.launchScreen != nil
        if !hasLaunchOverride {
            selectedTab = .play
        }
    }

    private func handleScenePhaseSideEffects(_ phase: ScenePhase) {
        switch phase {
        case .background:
            musicPlayer.cancelActiveFades()
            trimMemoryFootprint()
            Task { await playerSave.flushPendingSave() }
        case .inactive:
            musicPlayer.cancelActiveFades()
            Task { await playerSave.flushPendingSave() }
        case .active:
            evaluateLaunchLanding()
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
