import Foundation
import TrinketContent
import TrinketCore

public extension BattleCardCombatEngine {
    @discardableResult
    static func endTurnWithoutDraw(
        context: inout BattleState,
    ) -> [ActionEvent] {
        guard !context.isBattleOver, context.phase == .playerTurn else {
            assertionFailure("BattleCardCombatEngine.endTurnWithoutDraw called outside playerTurn")
            return []
        }

        let events = advanceRoundCommon(context: &context)
        if context.phase == .ended {
            return events
        }

        context.phase = .playerTurn

        context.pendingTurnDrawState = TurnDrawState(
            remaining: [.hero: 1, .companion: 1],
            tieWinner: context.turnCount.isMultiple(of: 2) ? .hero : .companion,
            heroHandCount: context.hand.cards.count { $0.owner == .hero },
            companionHandCount: context.hand.cards.count { $0.owner == .companion },
        )

        return events
    }

    @discardableResult
    static func drawNextTurnStartCard(
        context: inout BattleState,
    ) -> Bool {
        guard var state = context.pendingTurnDrawState else {
            return false
        }

        while true {
            let candidates = [BattleParticipant.hero, .companion].filter {
                state.remaining[$0, default: 0] > 0
            }
            guard !candidates.isEmpty else {
                context.pendingTurnDrawState = nil
                return false
            }

            let owner = pickBalancedOwner(
                candidates: candidates,
                isHandFull: context.hand.isFull,
                tieWinner: state.tieWinner,
                heroHandCount: state.heroHandCount,
                companionHandCount: state.companionHandCount,
            )

            state.remaining[owner, default: 0] -= 1
            let wasFull = context.hand.isFull
            if let card = drawOne(for: owner, context: &context) {
                if !wasFull {
                    if card.owner == .hero {
                        state.heroHandCount += 1
                    } else if card.owner == .companion {
                        state.companionHandCount += 1
                    }
                }
                context.pendingTurnDrawState = state
                if state.remaining.values.allSatisfy({ $0 <= 0 }) {
                    context.pendingTurnDrawState = nil
                }
                return true
            }
            state.remaining[owner] = 0
            context.pendingTurnDrawState = state
            continue
        }
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
            context.roster.clearControlStatusLinger(for: context.roster[owner].combatant)
        }
        context.phase = .playerTurn
        return events
    }

    @discardableResult
    static func promoteNextFromBuffer(
        context: inout BattleState,
    ) -> BattleCard? {
        let isAlive: (BattleParticipant) -> Bool = { context.roster[$0].isAlive }
        let result = context.hand.promoteNextFromBuffer(isOwnerAlive: isAlive)
        for card in result.discarded {
            putAbilityOnBottom(card.ability, owner: card.owner, context: &context)
        }
        return result.promoted
    }
}
