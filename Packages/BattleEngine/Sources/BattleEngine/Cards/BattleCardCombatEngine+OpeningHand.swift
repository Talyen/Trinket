import Foundation
import TrinketContent
import TrinketCore

extension BattleCardCombatEngine {
    static func dealCard(
        matching tier: AbilityTier,
        owner: BattleParticipant,
        context: inout BattleState,
    ) -> BattleCard? {
        drawSelecting(for: owner, context: &context) { $0.drawFirstEntry(where: { $0.tier == tier }) }
    }

    static func deal(
        _ ability: Ability,
        owner: BattleParticipant,
        context: inout BattleState,
    ) -> BattleCard {
        deal(CombatDeck.Entry(ability: ability, copyID: nil), owner: owner, context: &context)
    }

    static func deal(
        _ entry: CombatDeck.Entry,
        owner: BattleParticipant,
        context: inout BattleState,
    ) -> BattleCard {
        let heldMaximum = (context.hand.cards + context.hand.buffer).map(\.id).max() ?? 0
        context.nextCardID = max(context.nextCardID, heldMaximum) + 1
        let card = BattleCard(
            id: context.nextCardID, ability: entry.ability, owner: owner,
            deckCopyID: entry.copyID ?? context.nextCardID,
        )
        context.hand.append(card)
        return card
    }

    static func makeOpeningHandDealPlan(in context: inout BattleState) -> [OpeningHandDraw] {
        scheduledDraws(in: &context).map { OpeningHandDraw(owner: $0) }
    }

    static func scheduledDraws(in context: inout BattleState) -> [BattleParticipant] {
        var draws: [BattleParticipant] = []
        for _ in 0 ..< 3 {
            let scheduled = context.nextScheduledDrawOwner
            context.nextScheduledDrawOwner = scheduled == .hero ? .companion : .hero
            if context.roster.hero.isAlive, context.roster.companion.isAlive {
                draws.append(scheduled)
            } else if context.roster.hero.isAlive {
                draws.append(.hero)
            } else if context.roster.companion.isAlive {
                draws.append(.companion)
            }
        }
        return draws
    }

    static func discardPlayedCard(_ card: BattleCard, context: inout BattleState) {
        context.nextCardID = max(context.nextCardID, max(card.id, card.deckCopyID))
        switch card.owner {
        case .hero: context.heroDeck.discard(card)
        case .companion: context.companionDeck.discard(card)
        case .enemy: break
        }
    }

    static func putCardOnBottom(_ card: BattleCard, context: inout BattleState) {
        switch card.owner {
        case .hero: context.heroDeck.putOnBottom(card)
        case .companion: context.companionDeck.putOnBottom(card)
        case .enemy: break
        }
    }

    static func recoverCard(copyID: Int, owner: BattleParticipant, context: inout BattleState) -> BattleCard? {
        let entry: CombatDeck.Entry? = switch owner {
        case .hero: context.heroDeck.recover(copyID: copyID)
        case .companion: context.companionDeck.recover(copyID: copyID)
        case .enemy: nil
        }
        guard let entry else { return nil }
        return deal(entry, owner: owner, context: &context)
    }
}
