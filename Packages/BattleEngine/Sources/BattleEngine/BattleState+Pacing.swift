import Foundation
import TrinketCore

package extension BattleState {
    /// Scales an authored combat magnitude for the source side's fight pacing.
    func paced(_ amount: Int, sourceActorID: String?) -> Int {
        guard amount > 0,
              let sourceActorID,
              let side = FightPacing.side(for: sourceActorID, in: self)
        else { return amount }
        let multiplier = FightPacing.multiplier(side: side, isBoss: FightPacing.isBossEnemy(in: self), in: self)
        guard multiplier != 1 else { return amount }
        return CombatRounding.scaled(amount, multiplier: multiplier)
    }
}
