import Foundation
import TrinketContent
import TrinketCore

package extension BattleCardCombatEngine {
    @discardableResult
    static func endTurnWithoutDraw(
        context: inout BattleState,
    ) -> [ActionEvent] {
        guard !context.isBattleOver, context.phase == .playerTurn else {
            assertionFailure("BattleCardCombatEngine.endTurnWithoutDraw called outside playerTurn")
            return []
        }

        var events = advanceRoundCommon(context: &context)
        if context.phase == .ended {
            return events
        }

        context.phase = .playerTurn
        events.append(contentsOf: UniqueCombatEngine.startTurn(in: &context))

        context.heroDeck.recycleDiscards()
        context.companionDeck.recycleDiscards()
        let plannedDraws = scheduledDraws(in: &context)

        context.pendingTurnDrawState = TurnDrawState(plannedDraws: plannedDraws)

        return events
    }

    @discardableResult
    static func drawNextTurnStartCard(
        context: inout BattleState,
    ) -> Bool {
        guard var state = context.pendingTurnDrawState else {
            return false
        }

        while !state.plannedDraws.isEmpty {
            let nextOwner = state.plannedDraws.removeFirst()
            context.pendingTurnDrawState = state.plannedDraws.isEmpty ? nil : state
            if drawOne(for: nextOwner, context: &context) != nil {
                return true
            }
        }

        context.pendingTurnDrawState = nil
        return false
    }

    @discardableResult
    static func finalizeTurnStart(
        context: inout BattleState,
    ) -> [ActionEvent] {
        context.pendingTurnDrawState = nil
        var events: [ActionEvent] = []
        context.ownersSkippingThisPlayerTurn = skippingOwners(in: context)
        events.append(contentsOf: restoreManaAtPlayerTurnStart(context: &context))
        events.append(contentsOf: CombatTriggerEngine.atPlayerTurnStart(in: &context))
        for owner in [BattleParticipant.hero, .companion] {
            UniqueCombatEngine.recoverStunBeforeClearing(on: context.roster[owner].combatant, in: &context)
            context.roster.clearControlStatusLinger(for: context.roster[owner].combatant)
        }
        events.append(contentsOf: finishPlayerTurnStart(context: &context))
        return events
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
