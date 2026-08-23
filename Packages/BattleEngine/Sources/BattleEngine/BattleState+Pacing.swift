import Foundation
import TrinketCore

package extension BattleState {
    /// Scales an authored combat magnitude for the source side's fight pacing.
    func paced(_ amount: Int, sourceActorID: String?) -> Int {
        guard appliesFightPacing,
              amount > 0,
              let sourceActorID,
              let side = FightPacing.side(for: sourceActorID, in: self)
        else { return amount }
        // Recomputed per call; pool metrics are a few adds and boss-ness is a
        // dictionary lookup, negligible against the damage math it scales.
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

    /// Claims a once-per-action talent guard. Returns `true` only on the first
    /// claim within the current action (Mana Cocoon, Chaos Rift, …).
    mutating func claimActionGuard(_ kind: TalentActionGuardKey.Kind, actorID: String) -> Bool {
        let key = TalentActionGuardKey(kind: kind, actorID: actorID)
        guard talentActionGuardByActorID[key] != actionCount else { return false }
        talentActionGuardByActorID[key] = actionCount
        return true
    }

    /// Claims a once-per-battle talent guard. Returns `true` only the first time.
    mutating func claimBattleGuard(_ kind: TalentActionGuardKey.Kind, actorID: String) -> Bool {
        let key = TalentActionGuardKey(kind: kind, actorID: actorID)
        guard talentActionGuardByActorID[key] == nil else { return false }
        talentActionGuardByActorID[key] = 1
        return true
    }
}
