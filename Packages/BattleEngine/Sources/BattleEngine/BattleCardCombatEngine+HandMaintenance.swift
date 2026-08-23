import Foundation
import TrinketContent
import TrinketCore

extension BattleCardCombatEngine {
    /// Returns defeated-owner cards from hand/buffer to their decks so dead
    /// companion/hero cards cannot permanently fill hand slots.
    static func discardDefeatedOwnerCards(context: inout BattleState) {
        guard !context.roster.hero.isAlive || !context.roster.companion.isAlive else { return }
        var survivingHand: [BattleCard] = []
        for card in context.hand.cards {
            if context.roster[card.owner].isAlive {
                survivingHand.append(card)
            } else {
                putAbilityOnBottom(card.ability, owner: card.owner, context: &context)
            }
        }
        context.hand = BattleHand(cards: survivingHand)

        var survivingBuffer = BattleHandBuffer()
        for card in context.handBuffer.cards {
            if context.roster[card.owner].isAlive {
                survivingBuffer.enqueue(card)
            } else {
                putAbilityOnBottom(card.ability, owner: card.owner, context: &context)
            }
        }
        context.handBuffer = survivingBuffer
    }

    /// Moves buffered cards into the hand in FIFO order until the hand is full.
    /// Skips defeated-owner cards (defensive; callers also purge before promote).
    static func promoteFromBuffer(context: inout BattleState) {
        guard !context.handBuffer.isEmpty else { return }
        while !context.hand.isFull {
            guard let card = context.handBuffer.dequeue() else { return }
            guard context.roster[card.owner].isAlive else {
                putAbilityOnBottom(card.ability, owner: card.owner, context: &context)
                continue
            }
            context.hand.append(card)
        }
    }
}
