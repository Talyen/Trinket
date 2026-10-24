import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct DrawAndPlayRegressionTests {
    @Test func `Pack Tactics draws the ally card before checking its Health cost`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.roster.companion.currentHealth = 1
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.companionDeck = CombatDeck(abilities: [.bloodOffering])

        let outcome = EffectHandlersTestSupport.dispatch(
            .drawCards(1),
            ability: .packTactics,
            source: battle.hero,
            target: battle.hero,
            battle: &battle,
        )

        #expect(!outcome.events.contains { $0.kind == .abilityDamage })
        #expect(battle.hand.cards.map(\.ability.id) == [Ability.bloodOffering.id])
        #expect(!outcome.events.contains { $0.abilityID == Ability.bloodOffering.id })
        #expect(battle.companionDeck.abilities.isEmpty)
        #expect(battle.roster.companion.currentHealth == 1)
    }

    @Test func `Feint cannot borrow a card from the partner's deck`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [AbilityCatalog.feint], companionAbilities: [.slash],
            enemyMaxHealth: 50, dealOpeningHand: false,
        )
        battle.heroDeck = CombatDeck()
        battle.companionDeck = CombatDeck(abilities: [.slash])
        let enemyHealth = battle.health(of: battle.enemy)

        let events = battle.performTestAction(AbilityCatalog.feint)

        #expect(!events.contains { $0.abilityID == Ability.slash.id })
        #expect(battle.health(of: battle.enemy) == enemyHealth)
        #expect(battle.companionDeck.abilities.first?.id == Ability.slash.id)
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == .evadeNextHit })
    }

    @Test(arguments: [1, 2])
    func `automatic collection leaves an unaffordable Block card in its deck`(count: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        let blocked = Ability(
            id: "block-cost", name: "Block Cost", tier: .basic,
            damageComponents: [DamageComponent(1)], blockCost: 3,
        )
        battle.heroDeck = CombatDeck(abilities: [blocked])
        battle.companionDeck = CombatDeck(abilities: [.slash, .block])
        DefensePoolEngine.set(2, on: battle.hero, in: &battle)
        let health = battle.health(of: battle.enemy)

        let outcome = EffectHandlersTestSupport.dispatch(
            .drawAndPlayCards(count), source: battle.hero, target: battle.hero, battle: &battle,
        )

        #expect(outcome.didApply == (count > 1))
        #expect(battle.heroDeck.abilities.map(\.id) == [blocked.id])
        #expect(battle.hand.isEmpty)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 2)
        #expect((battle.health(of: battle.enemy) < health) == (count > 1))
        #expect(!outcome.events.contains { $0.abilityID == blocked.id })
    }
}
