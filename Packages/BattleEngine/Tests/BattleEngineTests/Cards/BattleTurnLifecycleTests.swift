import Testing
import TrinketContent
@testable import BattleEngine

struct BattleTurnLifecycleTests {
    @Test func `opening settlement cannot grant Block twice or return after a custom hand command`() throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.blockPerTurn = 3
        var battle = BattleStateTestFactory.makeBattle(heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false)
        battle.drawOpeningHand()
        let settled = battle.roster.hero
        let eventCount = battle.events.count
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 3)
        #expect(battle.drawOpeningHand().events.isEmpty)
        #expect(battle.roster.hero == settled)
        #expect(battle.events.count == eventCount)

        var custom = BattleStateTestFactory.makeBattle(heroModifiers: profile, dealOpeningHand: false)
        let card = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &custom)
        try custom.playCard(cardID: card.id)
        #expect(custom.drawOpeningHand().events.isEmpty)
        #expect(BattleTestFixtures.shieldPoints(for: custom.hero, in: custom) == 0)
    }

    @Test func `End Turn settles the round and Mana before returning playable cards`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash], enemyMaxHealth: 1000, heroMaxMana: 10, heroMana: 0,
        )
        let card = try #require(battle.hand.cards.first)
        battle.endTurn()
        #expect(battle.turnCount == 1)
        #expect(battle.roster.hero.currentMana == 1)
        #expect(battle.isCardPlayable(card))
        #expect(battle.drawOpeningHand().events.isEmpty)
        #expect(battle.roster.hero.currentMana == 1)
    }
}
