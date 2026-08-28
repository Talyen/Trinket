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
            in: self
        )
        guard multiplier != 1 else { return amount }
        return CombatRounding.scaled(amount, multiplier: multiplier)
    }

    mutating func claimActionGuard(_ kind: TalentActionGuardKey.Kind, actorID: String) -> Bool {
        let key = TalentActionGuardKey(kind: kind, actorID: actorID)
        guard talentActionGuardByActorID[key] != actionCount else { return false }
        talentActionGuardByActorID[key] = actionCount
        return true
    }

    mutating func claimBattleGuard(_ kind: TalentActionGuardKey.Kind, actorID: String) -> Bool {
        let key = TalentActionGuardKey(kind: kind, actorID: actorID)
        guard talentActionGuardByActorID[key] == nil else { return false }
        talentActionGuardByActorID[key] = 1
        return true
    }

    mutating func claimTurnGuard(_ kind: TalentActionGuardKey.Kind, actorID: String) -> Bool {
        let key = TalentActionGuardKey(kind: kind, actorID: actorID)
        guard talentTurnGuardByActorID[key] != turnCount else { return false }
        talentTurnGuardByActorID[key] = turnCount
        return true
    }
}
