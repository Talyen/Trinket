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

    @Test func setupPolicyPrefersApplyingMissingDotOverChipDamage() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [],
            companionAbilities: [],
            enemyMaxHealth: 40,
            dealOpeningHand: false
        )
        battle.hand = BattleHand()
        battle.handBuffer = BattleHandBuffer()

        battle.nextCardID += 1
        let chip = BattleCard(
            id: battle.nextCardID,
            ability: Ability(
                id: "chip",
                name: "Chip",
                tier: .basic,
                directDamage: 2,
                description: "Chip"
            ),
            owner: .hero
        )
        battle.hand.append(chip)

        battle.nextCardID += 1
        let poison = BattleCard(
            id: battle.nextCardID,
            ability: Ability(
                id: "envenom",
                name: "Envenom",
                tier: .basic,
                directDamage: 0,
                description: "Poison",
                effects: [.poison(4)]
            ),
            owner: .hero
        )
        battle.hand.append(poison)

        let chosen = SetupAwareHeuristicPolicy().preferredPlayableCard(in: battle)
        #expect(chosen?.id == poison.id)
    }

    @Test func simulationPoliciesMakeRejectsUnknownIDs() {
        #expect(SimulationPolicies.make(id: SimulationPolicies.greedyID)?.id == SimulationPolicies.greedyID)
        #expect(SimulationPolicies.make(id: SimulationPolicies.setupID)?.id == SimulationPolicies.setupID)
        #expect(SimulationPolicies.make(id: "setup-v2") == nil)
    }
}
