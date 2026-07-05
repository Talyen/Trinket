import SwiftUI

enum ShellRefreshTrigger {
    case appear
    case selectedTab(AppTab)
    case activeBattleStarted
    case activeBattleEnded
}

extension AppState {
    func syncBattlePauseForCurrentTab() {
        guard battle.activeBattle != nil else { return }
        if selectedTab != .play {
            battle.isPaused = true
        }
    }

    func refreshMusicRoute(scenePhase: ScenePhase) {
        musicPlayer.refresh(
            selectedTab: selectedTab,
            preview: battle.preview,
            activeBattle: battle.activeBattle,
            sceneIsActive: scenePhase == .active,
            volume: options.musicVolume
        )
    }

    func applyShellRefresh(trigger: ShellRefreshTrigger, scenePhase: ScenePhase) {
        switch trigger {
        case .appear:
            syncBattlePauseForCurrentTab()
        case let .selectedTab(newTab):
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
        }
        refreshMusicRoute(scenePhase: scenePhase)
    }

    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase != .active, battle.activeBattle != nil {
            battle.isPaused = true
        }
        refreshMusicRoute(scenePhase: newPhase)
        if newPhase == .inactive || newPhase == .background {
            playerSave.flushPendingPersistIfNeeded()
        }
        if newPhase == .background {
            Task {
                await syncCoordinator.checkpointUploadIfNeeded()
            }
        } else if newPhase == .active {
            Task {
                await syncCoordinator.reconcileForegroundIfSafe()
            }
        }
    }
}
