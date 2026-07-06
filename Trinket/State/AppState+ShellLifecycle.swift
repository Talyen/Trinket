import Foundation
import SwiftUI

extension AppState {
    func shellDidAppear(scenePhase: ScenePhase) {
        if battle.activeBattle != nil, selectedTab != .play {
            battle.isPaused = true
        }
        refreshMusic(scenePhase: scenePhase)
    }

    func shellDidChangeTab(to newTab: AppTab, scenePhase: ScenePhase) {
        sessionState.selectedTab = newTab
        if battle.activeBattle != nil {
            // Leaving Play pauses combat; returning stays paused until the player resumes.
            battle.isPaused = true
        }
        refreshMusic(scenePhase: scenePhase)
    }

    func shellDidChangeActiveBattle(started: Bool, scenePhase: ScenePhase) {
        if started {
            battle.isPaused = selectedTab != .play
        } else {
            battle.isPaused = false
            musicPlayer.clearEncounterResumePositions()
        }
        refreshMusic(scenePhase: scenePhase)
    }

    func shellDidChangeScenePhase(_ newPhase: ScenePhase) {
        if newPhase != .active, battle.activeBattle != nil {
            battle.isPaused = true
        }
        handleScenePhaseSideEffects(newPhase)
        refreshMusic(scenePhase: newPhase)
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
        _ = phase
    }
}
