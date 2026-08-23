import Foundation
import TrinketContent
import TrinketCore

extension BattleCardCombatEngine {
    /// Removes the first `tier` ability from `owner`'s deck and deals it.
    static func dealCard(
        matching tier: AbilityTier,
        owner: BattleParticipant,
        context: inout BattleState
    ) -> BattleCard? {
        guard context.roster[owner].isAlive else { return nil }
        let ability: Ability? = switch owner {
        case .hero:
            context.heroDeck.drawFirst(where: { $0.tier == tier })
        case .companion:
            context.companionDeck.drawFirst(where: { $0.tier == tier })
        case .enemy:
            nil
        }
        guard let ability else { return nil }
        // Planned pulls select deterministically; the legacy random-owner pick
        // consumed one RNG draw per dealt card. Burn one here so the battle
        // RNG stream stays aligned and seeded combat rolls keep their pinned
        // outcomes under the new opening-hand composition.
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

    /// Guaranteed opening-hand slots: one Basic per living party member with a
    /// Basic in its loadout, plus one Skill from a coin-flip owner that has one.
    /// Slot order is shuffled so the paced deal animation varies. Uses an
    /// offset-seeded generator so battle RNG streams stay identical to
    /// pre-plan behavior — critical for seeded tests and simulations.
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
