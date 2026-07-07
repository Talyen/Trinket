import Foundation
import SwiftUI
import TrinketContent

enum AppActivityType: Equatable {
    case browsing
    case localBattle
    case serverTrackedBattle
}

extension AppState {
    var currentActivityType: AppActivityType {
        if battle.activeBattle != nil || sessionState.activeBattleStageID != nil {
            return .localBattle
        }
        return .browsing
    }

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

    func evaluateResumeRules() {
        let now = Date()
        let isCold = isColdLaunch
        isColdLaunch = false

        let elapsed = sessionState.lastBackgroundedTime.map { now.timeIntervalSince($0) } ?? .infinity

        if isCold {
            let hasLaunchOverride = AppEnvironment.shared.launchTab != nil || AppEnvironment.shared.launchScreen != nil
            if !hasLaunchOverride {
                selectedTab = .play
            }
            if !isSavedBattleValid() {
                sessionState.clearBattleState()
            }
        } else {
            switch currentActivityType {
            case .localBattle:
                if isSavedBattleValid() {
                    if elapsed < seamlessWindow {
                        if battle.activeBattle == nil, let stageID = sessionState.activeBattleStageID, let stage = GameContent.stage(id: stageID) {
                            startBattle(for: stage)
                        }
                        selectedTab = .play
                    } else {
                        if battle.activeBattle != nil {
                            let oldChange = battle.onBattleStateChange
                            battle.onBattleStateChange = nil
                            battle.activeBattle = nil
                            battle.onBattleStateChange = oldChange
                        }
                        selectedTab = .play
                    }
                } else {
                    if battle.activeBattle != nil {
                        battle.endBattle()
                    }
                    selectedTab = .play
                    sessionState.clearBattleState()
                }
            case .browsing:
                if elapsed < seamlessWindow {
                    // Resume exact tab
                } else {
                    selectedTab = .play
                    sessionState.clearBattleState()
                }
            case .serverTrackedBattle:
                break
            }
        }
    }

    private func handleScenePhaseSideEffects(_ phase: ScenePhase) {
        if phase == .active {
            evaluateResumeRules()
        } else if phase == .background {
            sessionState.lastBackgroundedTime = Date()
        }
    }
}
