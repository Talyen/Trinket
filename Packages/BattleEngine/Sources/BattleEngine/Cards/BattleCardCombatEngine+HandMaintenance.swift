import Foundation
import TrinketContent
import TrinketCore

extension BattleCardCombatEngine {
    static func purgeControlledOwnerCards(
        for owner: BattleParticipant,
        context: inout BattleState,
    ) {
        guard owner.isPartyMember else { return }

        let removed = context.hand.removeAll { $0.owner == owner }
        for card in removed {
            putAbilityOnBottom(card.ability, owner: owner, context: &context)
        }
        promoteFromBuffer(context: &context)
    }

    static func discardDefeatedOwnerCards(context: inout BattleState) {
        guard !context.roster.hero.isAlive || !context.roster.companion.isAlive else { return }

        let removed = context.hand.removeAll { !context.roster[$0.owner].isAlive }
        for card in removed {
            putAbilityOnBottom(card.ability, owner: card.owner, context: &context)
        }
    }

    static func promoteFromBuffer(context: inout BattleState) {
        let isAlive: (BattleParticipant) -> Bool = { context.roster[$0].isAlive }
        let discarded = context.hand.promoteFromBuffer(isOwnerAlive: isAlive)
        for card in discarded {
            putAbilityOnBottom(card.ability, owner: card.owner, context: &context)
        }
    }
}
