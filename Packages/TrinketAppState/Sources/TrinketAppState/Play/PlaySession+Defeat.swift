import BattleEngine
import Foundation
import TrinketContent
import TrinketFeatureContracts
import TrinketPersistence

public extension PlaySession {
    func settleDefeatRewards(_ configuration: BattleRunConfiguration, at date: Date = Date()) -> BattleRewardSettlement? {
        guard let presentation = battlePresentation(for: configuration) else { return nil }
        return battleCompletion.settleDefeat(configuration, presentation: presentation, at: date)
    }

    func completeDefeat(
        _ configuration: BattleRunConfiguration,
        settlement: BattleRewardSettlement,
        action: BattleDefeatAction,
    ) -> BattleCompletionResult {
        guard let presentation = battlePresentation(for: configuration) else { return .unavailable }
        let result = battleCompletion.claimDefeat(configuration, presentation: presentation, settlement: settlement)
        guard result.didComplete else {
            if result == .persistenceFailed {
                playerSave.retrySaveAction(key: SaveRetryKey.defeat(configuration.id)) { [weak self] in
                    guard let self, battle.activeBattle?.id == configuration.id,
                          let refreshed = settleDefeatRewards(configuration) else { return }
                    _ = completeDefeat(configuration, settlement: refreshed, action: action)
                }
            }
            return result
        }
        switch action {
        case .retry:
            _ = restartActiveBattle()
            return battle.activeBattle?.id != configuration.id ? .completed : .unavailable
        case .leave:
            endBattleReturningToOrigin()
            return .completed
        }
    }
}
