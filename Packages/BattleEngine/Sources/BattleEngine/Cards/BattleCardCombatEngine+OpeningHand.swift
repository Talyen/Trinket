import Foundation
import TrinketContent
import TrinketCore

extension BattleCardCombatEngine {
    static func dealCard(
        matching tier: AbilityTier,
        owner: BattleParticipant,
        context: inout BattleState,
    ) -> BattleCard? {
        drawSelecting(for: owner, context: &context) { $0.drawFirst(where: { $0.tier == tier }) }
    }

    static func deal(
        _ ability: Ability,
        owner: BattleParticipant,
        context: inout BattleState,
    ) -> BattleCard {
        context.nextCardID += 1
        let card = BattleCard(id: context.nextCardID, ability: ability, owner: owner)
        context.hand.append(card)
        return card
    }

    static func makeOpeningHandDealPlan(in context: BattleState) -> [OpeningHandDraw] {
        var planRng = SeededRandomNumberGenerator(
            seed: context.rng.seed &+ 0x9E37_79B9_7F4A_7C15,
        )
        func hasTier(_ tier: AbilityTier, for owner: BattleParticipant) -> Bool {
            context.roster[owner].combatant.abilityLoadout.ability(for: tier) != nil
        }
        var plan: [OpeningHandDraw] = []
        if context.roster.hero.isAlive, hasTier(.basic, for: .hero) {
            plan.append(OpeningHandDraw(owner: .hero, tier: .basic))
        }
        let skillOwners = [BattleParticipant.hero, .companion].filter {
            context.roster[$0].isAlive && hasTier(.skill, for: $0)
        }
        if let owner = skillOwners.randomElement(using: &planRng) {
            plan.append(OpeningHandDraw(owner: owner, tier: .skill))
        }
        if context.roster.companion.isAlive, hasTier(.basic, for: .companion) {
            plan.append(OpeningHandDraw(owner: .companion, tier: .basic))
        }
        return plan
    }
}
