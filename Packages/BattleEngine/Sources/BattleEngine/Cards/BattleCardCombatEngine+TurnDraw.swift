import Foundation
import TrinketContent
import TrinketCore

package extension BattleCardCombatEngine {
    static func endTurnWithoutDraw(
        context: inout BattleState,
    ) async {
        guard !context.isBattleOver, context.phase == .playerTurn else {
            return
        }

        context.turnState = .resolving
        await advanceRoundCommon(context: &context)
        if context.phase == .ended {
            return
        }

        UniqueCombatEngine.startTurn(in: &context)

        context.heroDeck.recycleDiscards()
        context.companionDeck.recycleDiscards()
        let plannedDraws = scheduledDraws(in: &context)

        context.turnState = .drawing(plannedDraws)
    }

    @discardableResult
    static func drawNextTurnStartCard(
        context: inout BattleState,
    ) -> Bool {
        while let owner = context.turnState.nextDraw(opening: false) {
            if drawOne(for: owner, context: &context) != nil {
                return true
            }
        }

        return false
    }

    static func finalizeTurnStart(
        context: inout BattleState,
    ) async {
        guard context.turnState.beginTurnStart(opening: false) else { return }
        context.ownersSkippingThisPlayerTurn = skippingOwners(in: context)
        await CombatTriggerEngine.atPlayerTurnStart(in: &context)
        for owner in [BattleParticipant.hero, .companion] {
            UniqueCombatEngine.recoverStunBeforeClearing(on: context.roster[owner].combatant, in: &context)
            context.roster.clearControlStatusLinger(for: context.roster[owner].combatant)
        }
        await finishPlayerTurnStart(context: &context)
    }

    @discardableResult
    static func promoteNextFromBuffer(
        context: inout BattleState,
    ) -> BattleCard? {
        let isAlive: (BattleParticipant) -> Bool = { context.roster[$0].isAlive }
        let result = context.hand.promoteNextFromBuffer(isOwnerAlive: isAlive)
        for card in result.discarded {
            putCardOnBottom(card, context: &context)
        }
        return result.promoted
    }
}
