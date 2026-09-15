import Foundation
import TrinketCore

/// Turn and pacing guards on the BattleState facade: automatic-play scoping,
/// player-turn numbering, fight-pacing scaling, and talent claim guards.
package extension BattleState {
    mutating func withAutomaticPlay(_ body: (inout BattleState) throws -> [ActionEvent]) rethrows -> [ActionEvent] {
        resolution.beginAutomaticPlay()
        defer { resolution.endAutomaticPlay() }
        return try body(&self)
    }

    var playerTurnNumber: Int {
        turnCount + 1
    }

    func isPlayerTurn(every interval: Int, startingAt first: Int? = nil) -> Bool {
        let first = first ?? interval
        return interval > 0 && playerTurnNumber >= first && (playerTurnNumber - first).isMultiple(of: interval)
    }

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
