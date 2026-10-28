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
        #expect(battle.roster.hero.talents.dodgeChanceBonus(atTurn: battle.turnCount) == 0.5)
    }

    @Test func `feint draws a manual card and grants Dodge until the next turn`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 100, enemyMaxHealth: 100, dealOpeningHand: false, appliesFightPacing: false,
        )
        context.heroDeck = CombatDeck(abilities: [.slash])
        let enemyBefore = context.health(of: context.enemy)

        let feintEvents = context.performTestAction(AbilityCatalog.feint)
        #expect(!feintEvents.contains { $0.abilityID == Ability.slash.id && $0.kind == .abilityDamage })
        #expect(context.health(of: context.enemy) == enemyBefore)
        #expect(context.heroDeck.isEmpty)
        #expect(context.hand.cards.map(\.ability.id) == [Ability.slash.id])
        #expect(!context.activeEffects(of: context.hero).contains { $0.effect == .evadeNextHit })
        #expect(DamagePipeline.dodgeChance(for: context.hero, attackerID: context.enemy.id, in: context) == 0.6)
        #expect(context.effectSummaries(of: context.hero).contains { $0.keyword == .dodge && $0.text.contains("+50%") })

        let enemyAttack = Ability(
            id: "enemy-attack",
            name: "Enemy Attack",
            tier: .basic,
            directDamage: 4,
            damageKeyword: .physical,
            criticalChanceBonus: -1,
        )
        _ = context.performTestAction(enemyAttack, from: .enemy, to: .hero)
        #expect(DamagePipeline.dodgeChance(for: context.hero, attackerID: context.enemy.id, in: context) == 0.6)
        context.roster.mutateRuntime(for: context.hero) { $0.talents.grantDodgeUntilNextTurn(0.2) }
        #expect(DamagePipeline.dodgeChance(for: context.hero, attackerID: context.enemy.id, in: context) == 0.75)
        _ = context.endTurn()
        #expect(DamagePipeline.dodgeChance(for: context.hero, attackerID: context.enemy.id, in: context) == 0.1)
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
