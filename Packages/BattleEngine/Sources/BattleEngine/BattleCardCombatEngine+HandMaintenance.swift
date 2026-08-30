import Foundation
import TrinketContent
import TrinketCore

extension BattleCardCombatEngine {
    static func purgeControlledOwnerCards(
        for owner: BattleParticipant,
        context: inout BattleState
    ) {
        guard owner.isPartyMember else { return }

        var removedAbilities: [Ability] = []
        let survivingHand = context.hand.cards.filter { card in
            guard card.owner == owner else { return true }
            removedAbilities.append(card.ability)
            return false
        }
        context.hand = BattleHand(cards: survivingHand)

        var survivingBuffer = BattleHandBuffer()
        for card in context.handBuffer.cards {
            if card.owner == owner {
                removedAbilities.append(card.ability)
            } else {
                survivingBuffer.enqueue(card)
            }
        }
        context.handBuffer = survivingBuffer

        for ability in removedAbilities {
            putAbilityOnBottom(ability, owner: owner, context: &context)
        }
        promoteFromBuffer(context: &context)
    }

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
