import SwiftUI

extension AppState {
    func syncBattlePauseForCurrentTab() {
        guard battle.activeBattle != nil else { return }
        if selectedTab != .play {
            battle.isPaused = true
        }
    }

    func refreshMusicRoute(scenePhase: ScenePhase) {
        let route = musicDirector.route(
            selectedTab: selectedTab,
            preview: battle.preview,
            activeBattle: battle.activeBattle,
            sceneIsActive: scenePhase == .active,
            musicVolume: options.musicVolume
        )
        musicPlayer.update(route: route, volume: options.musicVolume)
    }

    func handleSelectedTabChange(_ newTab: AppTab, scenePhase: ScenePhase) {
        sessionState.selectedTab = newTab
        if battle.activeBattle != nil {
            // Leaving Play pauses combat; returning stays paused until the player resumes.
            battle.isPaused = true
        }
        refreshMusicRoute(scenePhase: scenePhase)
    }

    func handleActiveBattleStarted(scenePhase: ScenePhase) {
        battle.isPaused = selectedTab != .play
        refreshMusicRoute(scenePhase: scenePhase)
    }

    func handleActiveBattleEnded(scenePhase: ScenePhase) {
        battle.isPaused = false
        refreshMusicRoute(scenePhase: scenePhase)
        musicPlayer.clearEncounterResumePositions()
    }

    func handleMusicPreviewChange(scenePhase: ScenePhase) {
        refreshMusicRoute(scenePhase: scenePhase)
    }

    func handleMusicVolumeChange(scenePhase: ScenePhase) {
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

    func handleShellAppear(scenePhase: ScenePhase) {
        syncBattlePauseForCurrentTab()
        refreshMusicRoute(scenePhase: scenePhase)
    }
}
