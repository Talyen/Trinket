import Foundation
import TrinketContent
import TrinketCore

extension BattleCardCombatEngine {
    static func dealCard(
        matching tier: AbilityTier,
        owner: BattleParticipant,
        context: inout BattleState
    ) -> BattleCard? {
        guard canDrawFromDeck(for: owner, in: context), let keyPath = deckKeyPath(for: owner) else { return nil }
        guard let ability = context[keyPath: keyPath].drawFirst(where: { $0.tier == tier }) else { return nil }
        _ = context.rng.next()
        return deal(ability, owner: owner, context: &context)
    }

    static func deal(
        _ ability: Ability,
        owner: BattleParticipant,
        context: inout BattleState
    ) -> BattleCard {
        context.nextCardID += 1
        let card = BattleCard(id: context.nextCardID, ability: ability, owner: owner)
        if context.hand.isFull {
            context.handBuffer.enqueue(card)
        } else {
            context.hand.append(card)
        }
        return card
    }

    static func makeOpeningHandDealPlan(in context: BattleState) -> [OpeningHandDraw] {
        var planRng = SeededRandomNumberGenerator(
            seed: context.rng.seed &+ 0x9E37_79B9_7F4A_7C15
        )
        func hasTier(_ tier: AbilityTier, for owner: BattleParticipant) -> Bool {
            context.roster[owner].combatant.abilityLoadout.ability(for: tier) != nil
        }
        var plan: [OpeningHandDraw] = []
        let basicOwners = [BattleParticipant.hero, .companion].filter {
            context.roster[$0].isAlive && hasTier(.basic, for: $0)
        }
        for owner in basicOwners {
            plan.append(OpeningHandDraw(owner: owner, tier: .basic))
        }
        let skillOwners = [BattleParticipant.hero, .companion].filter {
            context.roster[$0].isAlive && hasTier(.skill, for: $0)
        }
        if let owner = skillOwners.randomElement(using: &planRng) {
            plan.append(OpeningHandDraw(owner: owner, tier: .skill))
        }
        plan.shuffle(using: &planRng)
        return plan
    }
}
