import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CombatBoundaryRegressionTests {
    @Test(arguments: [false, true])
    func `phoenix feather revival retains card feedback identity`(automatic: Bool) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.companion.currentHealth = 0
        let events: [ActionEvent]
        if automatic {
            events = try CombatExecutor.run { try await battle.withAutomaticPlay { context in
                let card = BattleCardCombatEngine.deal(.phoenixFeather, owner: .hero, context: &context)
                return try await BattleCardCombatEngine.playDrawnCard(card, context: &context)
            } }
        } else {
            let card = BattleCardCombatEngine.deal(.phoenixFeather, owner: .hero, context: &battle)
            events = try battle.playCard(cardID: card.id)
        }

        let revival = try #require(events.first {
            $0.effectKind == .instantHeal && $0.targetID == battle.companion.id
        })
        #expect(battle.health(of: battle.companion) == 1)
        #expect(revival.abilityID == Ability.phoenixFeather.id)
        #expect(revival.actorID == battle.hero.id)
        #expect(revival.origin == (automatic ? .automatic : .direct))
    }

    @Test func `turn start Mana restoration stops when the first owner's reaction wins`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.onGainManaHealFlat = 1
        profile.triggers.onHealDealHoly = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxMana: 3),
            companion: CombatantFixtures.passiveCompanion(maxMana: 3),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10, enemyHealth: 1, heroMana: 0, companionMana: 0,
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        battle.roster.enemy.hasConsumedDeathsDoor = true

        let events = CombatExecutor.run { await BattleCardCombatEngine.restoreManaAtPlayerTurnStart(context: &battle) }

        #expect(battle.isEnemyDefeated)
        #expect(battle.mana(of: battle.hero) == 1)
        #expect(battle.mana(of: battle.companion) == 0)
        #expect(!events.contains { $0.keyword == .mana && $0.targetID == battle.companion.id })
    }
}
