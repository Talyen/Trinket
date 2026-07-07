import Foundation
import SwiftUI

extension AppState {
    func shellDidAppear(scenePhase: ScenePhase) {
        shellScenePhase = scenePhase
        if battle.activeBattle != nil, selectedTab != .play {
            battle.isPaused = true
        }
        refreshMusic(scenePhase: scenePhase)
        syncBattleTickLoop()
    }

    func shellDidChangeTab(to newTab: AppTab, scenePhase: ScenePhase) {
        shellScenePhase = scenePhase
        sessionState.selectedTab = newTab
        if battle.activeBattle != nil {
            // Leaving Play pauses combat; returning stays paused until the player resumes.
            battle.isPaused = true
        }
        refreshMusic(scenePhase: scenePhase)
        syncBattleTickLoop()
    }

    func shellDidChangeActiveBattle(started: Bool, scenePhase: ScenePhase) {
        shellScenePhase = scenePhase
        if started {
            battle.isPaused = selectedTab != .play
        } else {
            battle.isPaused = false
            musicPlayer.clearEncounterResumePositions()
        }
        refreshMusic(scenePhase: scenePhase)
        syncBattleTickLoop()
    }

    func shellDidChangeScenePhase(_ newPhase: ScenePhase) {
        shellScenePhase = newPhase
        if newPhase != .active, battle.activeBattle != nil {
            battle.isPaused = true
        }
        handleScenePhaseSideEffects(newPhase)
        refreshMusic(scenePhase: newPhase)
        syncBattleTickLoop()
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
        switch phase {
        case .background:
            musicPlayer.cancelActiveFades()
            trimMemoryFootprintForBackground()
            Task { await playerSave.flushPendingSave() }
        case .inactive:
            musicPlayer.cancelActiveFades()
        case .active:
            break
        @unknown default:
            break
        }
    }
}
