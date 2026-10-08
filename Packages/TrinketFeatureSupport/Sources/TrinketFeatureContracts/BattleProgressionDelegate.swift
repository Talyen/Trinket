import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

/// Application-owned reward operations. A nil date uses the application's reward clock.
@MainActor
public protocol BattleProgressionDelegate: AnyObject {
    func settleBattleRewards(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards: [ResourceAmount]?,
        at date: Date?,
    ) -> BattleRewardSettlement?
    func settleDefeatRewards(_ configuration: BattleRunConfiguration, at date: Date?) -> BattleRewardSettlement?
    func completeActiveBattle(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards: [ResourceAmount]?,
        settlement: BattleRewardSettlement?,
        defersPresentationExit: Bool,
    ) -> BattleCompletionResult
    func completeDefeat(
        _ configuration: BattleRunConfiguration,
        settlement: BattleRewardSettlement,
        action: BattleDefeatAction,
    ) -> BattleCompletionResult
    func finishBattleRewardPresentation(configurationID: UUID)
}
