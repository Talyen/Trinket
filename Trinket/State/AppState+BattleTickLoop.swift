import Foundation
import SwiftUI

extension AppState {
    private static let battleTickIdlePollInterval: Duration = .seconds(1)
    private static let battleTickIdlePollTolerance: Duration = .milliseconds(100)

    var battleTickInterval: Duration {
        let seconds = AppEnvironment.shared.battleTickInterval ?? AppEnvironment.defaultBattleTickInterval
        return .seconds(seconds)
    }

    private var battleTickTolerance: Duration {
        .milliseconds(80)
    }

    func syncBattleTickLoop() {
        if shouldRunBattleTickLoop {
            startBattleTickLoopIfNeeded()
        } else {
            stopBattleTickLoop()
        }
    }

    private var shouldRunBattleTickLoop: Bool {
        battle.activeBattle != nil
    }

    var canAdvanceBattleTicks: Bool {
        guard battle.activeBattle != nil else { return false }
        guard !battle.isPaused else { return false }
        guard shellScenePhase == .active else { return false }
        guard selectedTab == .play else { return false }
        guard !battle.isShowingVictory, !battle.isShowingDefeat else { return false }
        return true
    }

    private func startBattleTickLoopIfNeeded() {
        guard battleTickTask == nil, shouldRunBattleTickLoop else { return }

        battleTickTask = Task { @MainActor [weak self] in
            let clock = SuspendingClock()
            defer { self?.battleTickTask = nil }

            while let self, !Task.isCancelled, self.shouldRunBattleTickLoop {
                if self.canAdvanceBattleTicks,
                   let configuration = self.battle.activeBattle {
                    self.handleBattlePeriodicTick(configuration: configuration, at: .now)
                    try? await clock.sleep(
                        for: self.battleTickInterval,
                        tolerance: self.battleTickTolerance
                    )
                } else {
                    try? await clock.sleep(
                        for: Self.battleTickIdlePollInterval,
                        tolerance: Self.battleTickIdlePollTolerance
                    )
                }
            }
        }
    }

    private func stopBattleTickLoop() {
        battleTickTask?.cancel()
        battleTickTask = nil
    }
}
