import BattleEngine
import Foundation

extension BattleSession {
    /// Drives deterministic Auto Battle decisions while leaving card geometry and
    /// cast presentation in the SwiftUI hand lane.
    func driveAutoBattle(
        isCardCastActive: @escaping @MainActor () -> Bool,
        isManualInteractionActive: @escaping @MainActor () -> Bool,
        playCard: @escaping @MainActor (BattleCard) -> Bool
    ) async {
        while !Task.isCancelled, isAutoBattleEnabled {
            guard activeBattle != nil, outcome == nil else { return }

            if isSuspendedForScenePhase
                || !canEndTurn
                || isShowingBattleLog
                || overlayCombatantDetail != nil
                || overlayAbilityDetail != nil
                || isManualInteractionActive()
                || isCardCastActive() {
                await waitForAutoBattleRetry()
                continue
            }

            guard let card = hand.first(where: { isCardPlayable($0) }) else {
                if pendingAutoEndTask == nil {
                    scheduleAutoEndIfNeeded()
                }
                await waitForAutoBattleRetry()
                continue
            }

            guard playCard(card) else { return }
            guard !Task.isCancelled, isAutoBattleEnabled, outcome == nil else { return }

            while !Task.isCancelled, isAutoBattleEnabled, isCardCastActive() {
                await waitForAutoBattleRetry()
            }
        }
    }

    private func waitForAutoBattleRetry() async {
        try? await Task.sleep(for: .milliseconds(50))
    }
}
