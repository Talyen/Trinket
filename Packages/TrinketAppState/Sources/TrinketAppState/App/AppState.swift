import BattleEngine
import Foundation
import Observation
import os
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence
import UIKit

let appStateLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "AppState",
)

@MainActor
@Observable
public final class AppState {
    public let environment: AppEnvironment
    public let playerSave: PlayerSaveStore
    public let shellSession: ShellSession
    let musicPlayer: MusicPlayer
    public let sfxPlayer: SFXPlayer
    public let options: OptionsStore
    public let play: PlaySession
    public let fullGame: FullGameStore
    var preparedContentAccess = ContentAccessPolicy.free

    private(set) var pendingCollectionPresentation: LaunchPresentation?
    public var selectedTab: AppTab {
        get { shellSession.selectedTab }
        set { shellSession.selectedTab = newValue }
    }

    public init(
        environment: AppEnvironment = .shared,
        playerSave: PlayerSaveStore? = nil,
        userDefaults: UserDefaults? = nil,
        fullGame: FullGameStore? = nil,
        makeBattleRuntime: (BattlePresentationDependencies) -> any BattleRuntime,
        battleRewardDate: @escaping @MainActor () -> Date = { Date() },
    ) throws {
        self.environment = environment
        #if DEBUG
        self.fullGame = fullGame ?? (environment.developmentUnlocked ? .developmentUnlocked() : FullGameStore())
        #else
        self.fullGame = fullGame ?? FullGameStore()
        #endif
        let resolvedDefaults = userDefaults ?? .standard

        let dependencies = try Self.makeBootstrapDependencies(
            environment: environment,
            playerSave: playerSave,
            userDefaults: resolvedDefaults,
        )

        self.playerSave = dependencies.playerSave
        shellSession = dependencies.shellSession
        musicPlayer = dependencies.musicPlayer
        sfxPlayer = dependencies.sfxPlayer
        options = dependencies.options
        pendingCollectionPresentation = dependencies.pendingCollectionPresentation

        let resolvedBattle = Self.resolveBattleRuntime(
            factory: makeBattleRuntime,
            dependencies: dependencies,
        )
        play = PlaySession(
            playerSave: dependencies.playerSave,
            shellSession: dependencies.shellSession,
            battle: resolvedBattle,
            options: dependencies.options,
            sfxPlayer: dependencies.sfxPlayer,
            pendingDestination: dependencies.pendingPlayDestination,
            battlePerformanceScenario: environment.battlePerformanceScenario,
            battleRewardDate: battleRewardDate,
        )
        finishBootstrap(environment: environment)
        installCloudSynchronization()
    }

    private static func resolveBattleRuntime(
        factory: (BattlePresentationDependencies) -> any BattleRuntime,
        dependencies: BootstrapDependencies,
    ) -> any BattleRuntime {
        let musicPlayer = dependencies.musicPlayer
        let sfxPlayer = dependencies.sfxPlayer
        let options = dependencies.options
        return factory(BattlePresentationDependencies(
            readMusicPlayback: { musicPlayer.readPlayback() },
            bossLyricsEnabled: { options.bossLyricsEnabled },
            playSFX: { ids in
                sfxPlayer.playAll(
                    ids,
                    volume: options.effectsVolume,
                )
            },
            warmSFX: { ids, concurrentPlayerCount in
                sfxPlayer.warm(
                    ids,
                    concurrentPlayerCount: concurrentPlayerCount,
                )
            },
            hapticsEnabled: {
                options.hapticsEnabled
            },
            rememberAutoBattlePreference: {
                options.rememberAutoBattlePreference
            },
            autoBattleEnabled: {
                options.autoBattleEnabled
            },
            setAutoBattleEnabled: { enabled in
                options.autoBattleEnabled = enabled
            },
        ))
    }

    public func consumePendingCollectionPresentation() -> LaunchPresentation? {
        defer { pendingCollectionPresentation = nil }
        return pendingCollectionPresentation
    }

    @discardableResult
    public func confirmStarterHero(_ heroID: String) -> SaveActionAttempt<Bool> {
        playerSave.confirmStarterHero(heroID)
    }

    @discardableResult
    public func completeStarterSelection(companionID: String) -> SaveActionAttempt<Bool> {
        playerSave.completeStarterSelection(companionID: companionID).map { committed in
            if committed {
                shellSession.selectedTab = .play
            }
            return committed
        }
    }

    @discardableResult
    public func resetGameplayProgress() -> SaveActionAttempt<Bool> {
        let result = SaveActionAttempt.catching(failureValue: false) {
            try playerSave.resetGameplayProgress()
            clearTransientPlaySession()
            return true
        }
        if let error = result.failure {
            appStateLogger.error("Failed to reset gameplay progress: \(error.localizedDescription, privacy: .public)")
        }
        return result
    }

    @discardableResult
    public func unlockAllContent() -> SaveActionAttempt<Bool> {
        let result = SaveActionAttempt.catching(failureValue: false) {
            try playerSave.unlockAllContent()
            clearTransientPlaySession()
            return true
        }
        if let error = result.failure {
            appStateLogger.error("Failed to unlock all content: \(error.localizedDescription, privacy: .public)")
        }
        return result
    }

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
        case .selectedTabChanged:
            break
        }

        refreshMusic(scenePhase: scenePhase)
        applyIdleTimerPolicy(scenePhase: scenePhase)
    }

    /// Single entry for shell settle points that need both purchase
    /// reconciliation and shell reconciliation (battle ended, foreground).
    /// Purchase sync is deferred while gameplay is active, so calling this
    /// from encounter-exit paths is safe but may no-op until play settles.
    public func shellDidSettle(_ trigger: ShellReconcileTrigger, scenePhase: ScenePhase) {
        synchronizePurchaseAccess()
        reconcileShellState(trigger, scenePhase: scenePhase)
    }

    private func applyIdleTimerPolicy(scenePhase: ScenePhase) {
        UIApplication.shared.isIdleTimerDisabled = scenePhase == .active
            && selectedTab == .play && play.battle.activeBattle != nil
    }

    @ObservationIgnored private var memoryPressureObserver: MainActorCleanup?
    @ObservationIgnored var cloudAccountObserver: MainActorCleanup?

    public func installMemoryPressureHandling() {
        #if canImport(UIKit)
        memoryPressureObserver = nil
        let observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            self?.trimMemoryFootprint()
        }
        memoryPressureObserver = MainActorCleanup {
            NotificationCenter.default.removeObserver(observer)
        }
        #endif
    }

    public func trimMemoryFootprint() {
        play.battle.trimMemoryFootprint(releaseBattleLog: true)
        if play.battle.lifecyclePhase == .idle {
            sfxPlayer.releaseResources()
        }
    }

    public func refreshMusic(scenePhase: ScenePhase, volumeOverride: Double? = nil) {
        let volume = volumeOverride ?? options.musicVolume
        musicPlayer.update(
            route: musicRoute(scenePhase: scenePhase, musicVolume: volume),
            volume: volume,
            immediate: scenePhase != .active,
        )
        prepareMutedMusicIfNeeded(scenePhase: scenePhase)
    }

    public func applyMusicVolumeLive(_ volume: Double, scenePhase: ScenePhase) {
        if musicPlayer.canPreviewVolume {
            musicPlayer.setVolume(volume)
        } else if volume > 0 {
            refreshMusic(scenePhase: scenePhase, volumeOverride: volume)
        }
    }

    private func prepareMutedMusicIfNeeded(scenePhase: ScenePhase) {
        guard scenePhase == .active, options.musicVolume <= 0, selectedTab == .options else {
            return
        }

        if case let .track(request) = musicRoute(scenePhase: scenePhase, musicVolume: 1) {
            musicPlayer.prepare(request)
        }
    }

    private func musicRoute(scenePhase: ScenePhase, musicVolume: Double) -> MusicRoute {
        MusicRoute.resolve(
            selectedTab: selectedTab,
            activeBattle: play.battle.activeBattle,
            sceneIsActive: scenePhase == .active,
            musicVolume: musicVolume,
        )
    }

    private func handleScenePhaseSideEffects(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            play.battle.setSuspendedForScenePhase(true)
            musicPlayer.cancelActiveFades()
            playerSave.flushPendingPersistence()
            if phase == .background {
                trimMemoryFootprint()
            }
        case .active:
            play.battle.setSuspendedForScenePhase(false)
        @unknown default:
            break
        }
    }
}

public enum ShellReconcileTrigger {
    case activeBattleChanged(started: Bool)
    case scenePhaseChanged
    case selectedTabChanged
}
