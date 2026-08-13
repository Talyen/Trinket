import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct GreedyHeuristicPolicyTests {
    @Test func prefersLethalCardOverWeakerLeftmostCard() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [],
            companionAbilities: [],
            enemyMaxHealth: 5,
            dealOpeningHand: false
        )
        battle.hand = BattleHand()
        battle.handBuffer = BattleHandBuffer()

        battle.nextCardID += 1
        let weak = BattleCard(
            id: battle.nextCardID,
            ability: Ability(
                id: "chip",
                name: "Chip",
                tier: .basic,
                directDamage: 1,
                description: "Chip"
            ),
            owner: .hero
        )
        battle.hand.append(weak)

        battle.nextCardID += 1
        let lethal = BattleCard(
            id: battle.nextCardID,
            ability: Ability(
                id: "execute",
                name: "Execute",
                tier: .basic,
                directDamage: 5,
                description: "Execute"
            ),
            owner: .hero
        )
        battle.hand.append(lethal)

        let chosen = GreedyHeuristicPolicy().preferredPlayableCard(in: battle)
        #expect(chosen?.id == lethal.id)
        #expect(battle.hand.cards.first?.id == weak.id)
    }
}
