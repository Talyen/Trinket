import Foundation
import SwiftUI

extension AppState {
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
}
