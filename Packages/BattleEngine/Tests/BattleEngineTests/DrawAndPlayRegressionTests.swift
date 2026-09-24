import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DrawAndPlayRegressionTests {
    @Test func `Pack Tactics falls back when the ally cannot pay a card's Health cost`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.roster.companion.currentHealth = 1
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.companionDeck = CombatDeck(abilities: [.bloodOffering])

        let outcome = EffectHandlersTestSupport.dispatch(
            .drawAndPlayCards(1),
            ability: .packTactics,
            source: battle.hero,
            target: battle.hero,
            battle: &battle,
        )

        #expect(outcome.events.contains { $0.kind == .abilityDamage && $0.abilityID == Ability.slash.id })
        #expect(!outcome.events.contains { $0.abilityID == Ability.bloodOffering.id })
        #expect(battle.companionDeck.abilities.first?.id == Ability.bloodOffering.id)
    }

    @Test func `Shadowstep does not play a card from the partner's deck`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.shadowstep], companionAbilities: [.slash],
            enemyMaxHealth: 50, dealOpeningHand: false,
        )
        battle.heroDeck = CombatDeck()
        battle.companionDeck = CombatDeck(abilities: [.slash])
        let enemyHealth = battle.health(of: battle.enemy)

        let events = BattleTurnEngine.performAction(
            ability: .shadowstep, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )

        #expect(!events.contains { $0.abilityID == Ability.slash.id })
        #expect(battle.health(of: battle.enemy) == enemyHealth)
        #expect(battle.companionDeck.abilities.first?.id == Ability.slash.id)
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == .evadeNextHit })
    }
}
