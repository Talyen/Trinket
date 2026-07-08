import Foundation
import SwiftUI

extension AppState {
    private static let battleTickIdlePollInterval: Duration = .seconds(1)
    private static let battleTickIdlePollTolerance: Duration = .milliseconds(100)

    var battleTickInterval: Duration {
        let seconds = environment.battleTickInterval ?? AppEnvironment.defaultBattleTickInterval
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
        battle.activeBattle != nil && shellScenePhase == .active
    }

    var canAdvanceBattleTicks: Bool {
        guard battle.canAutoAdvanceTick(at: .now) else { return false }
        guard shellScenePhase == .active, selectedTab == .play else { return false }
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
                    if let earnedGold = self.battle.advanceAutoTick(
                        at: .now,
                        journey: self.journey.current,
                        homestead: self.homestead.current
                    ) {
                        self.grantBattleEarnedGold(earnedGold)
                        self.completeActiveBattle(configuration, battleEarnedGold: 0)
                    }
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
