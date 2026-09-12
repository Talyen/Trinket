import Foundation
import TrinketCore

package extension BattleState {
    func paced(_ amount: Int, sourceActorID: String?) -> Int {
        guard appliesFightPacing,
              amount > 0,
              let sourceActorID,
              let side = FightPacing.side(for: sourceActorID, in: self)
        else { return amount }
        let metrics = FightPacing.poolMetrics(in: self)
        let multiplier = FightPacing.multiplier(
            side: side,
            isBoss: FightPacing.isBossEnemy(in: self),
            metrics: metrics,
            in: self,
        )
        guard multiplier != 1 else { return amount }
        return CombatRounding.scaled(amount, multiplier: multiplier)
    }

    mutating func claimActionGuard(_ kind: TalentClaim, actorID: String) -> Bool {
        let cadence = resolution.actionID.map(CombatResolution.Cadence.action) ?? .standaloneAction(actionCount)
        return resolution.claim(.talent(kind), actorID: actorID, cadence: cadence)
    }

    mutating func claimBattleGuard(_ kind: TalentClaim, actorID: String) -> Bool {
        resolution.claim(.talent(kind), actorID: actorID, cadence: .battle)
    }

    mutating func claimTurnGuard(_ kind: TalentClaim, actorID: String) -> Bool {
        resolution.claim(.talent(kind), actorID: actorID, cadence: .turn(turnCount))
    }
}
