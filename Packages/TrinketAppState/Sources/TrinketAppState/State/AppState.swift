import BattleEngine
import Foundation
import Observation
import os
import SwiftUI
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence
import UIKit

let appStateLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "AppState"
)

@MainActor
@Observable
public final class AppState {
    public let environment: AppEnvironment
    public let playerSave: PlayerSaveStore
    public let shellSession: PlayerShellSessionStore
    let musicPlayer: MusicPlayer
    public let sfxPlayer: SFXPlayer
    public var shellScenePhase: ScenePhase = .active
    public var options: OptionsStore
    public var battle: BattleSession
    public let play: PlaySession

    private(set) var pendingCollectionPresentation: LaunchPresentation?
    public var selectedTab: AppTab {
        get { AppTab(shellSessionTab: shellSession.selectedTab) ?? .play }
        set { shellSession.selectedTab = PlayerShellSessionTab(rawValue: newValue.rawValue) ?? .play }
    }

    public init(
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

        let desiredTab = PlayerShellSessionTab(rawValue: dependencies.selectedTab.rawValue) ?? .play
        if shellSession.selectedTab != desiredTab {
            shellSession.selectedTab = desiredTab
        }
        if shellSession.mapScrollStageID != dependencies.mapScrollStageID {
            shellSession.mapScrollStageID = dependencies.mapScrollStageID
        }
        let resolvedBattle = BattleSession(
            presentationEnvironment: BattlePresentationEnvironment(
                playSFX: { ids in
                    dependencies.sfxPlayer.playAll(
                        ids,
                        volume: dependencies.options.effectsVolume
                    )
                },
                warmSFX: { ids, concurrentPlayerCount in
                    dependencies.sfxPlayer.warm(
                        ids,
                        concurrentPlayerCount: concurrentPlayerCount
                    )
                },
                hapticsEnabled: {
                    dependencies.options.hapticsEnabled
                },
                effectsVolume: {
                    dependencies.options.effectsVolume
                },
                shouldAutoSkipUltimateCinematic: { actorID, presentedActors in
                    dependencies.options.shouldAutoSkipUltimateCinematic(
                        actorID: actorID,
                        actorsWhoPresentedThisBattle: presentedActors
                    )
                }
            )
        )
        battle = resolvedBattle
        play = PlaySession(
            playerSave: dependencies.playerSave,
            shellSession: dependencies.shellSession,
            battle: resolvedBattle,
            options: dependencies.options,
            sfxPlayer: dependencies.sfxPlayer,
            pendingDestination: dependencies.pendingPlayDestination
        )
        finishBootstrap(environment: environment)
    }

    public func consumePendingCollectionPresentation() -> LaunchPresentation? {
        defer { pendingCollectionPresentation = nil }
        return pendingCollectionPresentation
    }

    public var persistenceStatusMessage: String? {
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

    /// True when the canonical player store could not be opened and persistence is in-memory.
    public var requiresPersistenceRecoveryAcknowledgement: Bool {
        playerSave.isPersistenceDegraded
    }

    @discardableResult
    public func resetGameplayProgress() -> Bool {
        do {
            try playerSave.resetGameplayProgress()
        } catch {
            appStateLogger.error(
                "Failed to reset gameplay progress: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
        clearTransientPlaySession()
        return true
    }

    /// Dev-only: unlocks all content/heroes/companions at level 20 for Simulator testing.
    @discardableResult
    public func unlockAllContent() -> Bool {
        do {
            try playerSave.unlockAllContent()
        } catch {
            appStateLogger.error(
                "Failed to unlock all content: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
        clearTransientPlaySession()
        return true
    }

    /// Ends any live encounter and resets shell session after a full progress rewrite.
    private func clearTransientPlaySession() {
        battle.endBattle()
        play.clearTransientState()
    }

    public func reconcileShellState(_ trigger: ShellReconcileTrigger, scenePhase: ScenePhase) {
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

    public func installMemoryPressureHandling() {
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

    public func trimMemoryFootprint() {
        battle.trimMemoryFootprint(releaseBattleLog: true)
        musicPlayer.trimMemoryFootprint()
        sfxPlayer.stopAll()
    }

    public func refreshMusic(scenePhase: ScenePhase, volumeOverride: Double? = nil) {
        let volume = volumeOverride ?? options.musicVolume
        musicPlayer.update(
            route: MusicRoute.resolve(
                selectedTab: selectedTab,
                activeBattle: battle.activeBattle,
                sceneIsActive: scenePhase == .active,
                musicVolume: volume
            ),
            volume: volume
        )
    }

    /// Options slider scrubbing: preview gain without persisting or mute-fading until commit.
    public func applyMusicVolumeLive(_ volume: Double, scenePhase: ScenePhase) {
        if musicPlayer.hasActivePlayback {
            musicPlayer.setVolume(volume)
        } else if volume > 0 {
            refreshMusic(scenePhase: scenePhase, volumeOverride: volume)
        }
    }

    /// Always land on Play unless a UI-test launch override selected another tab/screen.
    public func evaluateLaunchLanding() {
        let hasLaunchOverride = environment.launchTab != nil || environment.launchScreen != nil
        if !hasLaunchOverride {
            selectedTab = .play
        }
    }

    private func handleScenePhaseSideEffects(_ phase: ScenePhase) {
        switch phase {
        case .background:
            battle.setSuspendedForScenePhase(true)
            musicPlayer.cancelActiveFades()
            trimMemoryFootprint()
            shellSession.flushPendingPersistence()
            playerSave.flushPendingPersistence()
        case .inactive:
            battle.setSuspendedForScenePhase(true)
            musicPlayer.cancelActiveFades()
            shellSession.flushPendingPersistence()
            playerSave.flushPendingPersistence()
        case .active:
            // Launch tab is applied once during bootstrap / finishBootstrap.
            // Re-forcing Play on every foreground would wipe the persisted shell tab.
            battle.setSuspendedForScenePhase(false)
        @unknown default:
            break
        }
    }
}

public enum ShellReconcileTrigger {
    case appeared
    case tabChanged
    case activeBattleChanged(started: Bool)
    case scenePhaseChanged
}
