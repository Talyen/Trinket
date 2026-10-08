import BattleEngine
import Foundation
import TrinketContent
import TrinketFeatureContracts

public extension PlaySession {
    func settleDefeatRewards(_ configuration: BattleRunConfiguration, at date: Date? = nil) -> BattleRewardSettlement? {
        battleCoordinator.settleDefeat(configuration, at: date ?? battleRewardDate())
    }

    func completeDefeat(
        _ configuration: BattleRunConfiguration,
        settlement: BattleRewardSettlement,
        action: BattleDefeatAction,
    ) -> BattleCompletionResult {
        battleCoordinator.completeDefeat(configuration, settlement: settlement, action: action) { [weak self] in
            self?.finishBattleExit(for: [configuration.hero.combatant, configuration.companion.combatant])
        }
    }
}
