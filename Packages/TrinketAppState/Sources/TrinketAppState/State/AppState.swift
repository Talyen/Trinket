import BattleEngine
import Foundation
import Observation
import os
import SwiftUI
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
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
    public let shellSession: ShellSession
    let musicPlayer: MusicPlayer
    public let sfxPlayer: SFXPlayer
    public var options: OptionsStore
    public let play: PlaySession

    private(set) var pendingCollectionPresentation: LaunchPresentation?
    public var selectedTab: AppTab {
        get { shellSession.selectedTab }
        set { shellSession.selectedTab = newValue }
    }

    public init(
        environment: AppEnvironment = .shared,
        playerSave: PlayerSaveStore? = nil,
        userDefaults: UserDefaults? = nil,
        battleRuntime: (any BattleRuntime)? = nil,
        makeBattleRuntime: ((BattleRuntimeDependencies) -> any BattleRuntime)? = nil
    ) throws {
        self.environment = environment
        let resolvedDefaults = userDefaults ?? .standard

        let dependencies = try Self.makeBootstrapDependencies(
            environment: environment,
            playerSave: playerSave,
            userDefaults: resolvedDefaults
        )

        self.playerSave = dependencies.playerSave
        shellSession = dependencies.shellSession
        musicPlayer = dependencies.musicPlayer
        sfxPlayer = dependencies.sfxPlayer
        options = dependencies.options
        pendingCollectionPresentation = dependencies.pendingCollectionPresentation

        let resolvedBattle = Self.resolveBattleRuntime(
            explicit: battleRuntime,
            factory: makeBattleRuntime,
            dependencies: dependencies
        )
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

    private static func resolveBattleRuntime(
        explicit: (any BattleRuntime)?,
        factory: ((BattleRuntimeDependencies) -> any BattleRuntime)?,
        dependencies: BootstrapDependencies
    ) -> any BattleRuntime {
        explicit
            ?? factory?(BattleRuntimeDependencies(
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
                rememberAutoBattlePreference: {
                    dependencies.options.rememberAutoBattlePreference
                },
                autoBattleEnabled: {
                    dependencies.options.autoBattleEnabled
                },
                setAutoBattleEnabled: { enabled in
                    dependencies.options.autoBattleEnabled = enabled
                },
                shouldAutoSkipUltimateCinematic: { actorID, presentedActors in
                    dependencies.options.shouldAutoSkipUltimateCinematic(
                        actorID: actorID,
                        actorsWhoPresentedThisBattle: presentedActors
                    )
                }
            ))
            ?? BattleRuntimeStore()
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
        play.clearTransientState()
    }

    public func reconcileShellState(_ trigger: ShellReconcileTrigger, scenePhase: ScenePhase) {
        switch trigger {
        case let .activeBattleChanged(started):
            if !started {
                musicPlayer.clearEncounterResumePositions()
            }
        case .scenePhaseChanged:
            handleScenePhaseSideEffects(scenePhase)
        }

        refreshMusic(scenePhase: scenePhase)
    }

    private var memoryPressureObserver: (any NSObjectProtocol)?

    isolated deinit {
        if let memoryPressureObserver {
            NotificationCenter.default.removeObserver(memoryPressureObserver)
        }
    }

    public func installMemoryPressureHandling() {
        #if canImport(UIKit)
        if let memoryPressureObserver {
            NotificationCenter.default.removeObserver(memoryPressureObserver)
        }
        memoryPressureObserver = NotificationCenter.default.addObserver(
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

    public func trimMemoryFootprint() {
        play.battle.trimMemoryFootprint(releaseBattleLog: true)
        musicPlayer.clearEncounterResumePositions()
        sfxPlayer.stopAll()
    }

    public func refreshMusic(scenePhase: ScenePhase, volumeOverride: Double? = nil) {
        let volume = volumeOverride ?? options.musicVolume
        musicPlayer.update(
            route: MusicRoute.resolve(
                selectedTab: selectedTab,
                activeBattle: play.battle.activeBattle,
                battleStageID: play.battlePresentation(for: play.battle.activeBattle?.runKey)?.musicStageID,
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

    private func handleScenePhaseSideEffects(_ phase: ScenePhase) {
        switch phase {
        case .background:
            play.battle.setSuspendedForScenePhase(true)
            musicPlayer.cancelActiveFades()
            trimMemoryFootprint()
            playerSave.flushPendingPersistence()
        case .inactive:
            play.battle.setSuspendedForScenePhase(true)
            musicPlayer.cancelActiveFades()
            playerSave.flushPendingPersistence()
        case .active:
            // Cold launch lands on Play via bootstrap `selectedTab(environment:)`.
            // Re-forcing Play on every foreground would wipe the in-session shell tab.
            play.battle.setSuspendedForScenePhase(false)
        @unknown default:
            break
        }
    }
}

public enum ShellReconcileTrigger {
    case activeBattleChanged(started: Bool)
    case scenePhaseChanged
}
