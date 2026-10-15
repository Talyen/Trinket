import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct GoldGainCadenceRegressionTests {
    @Test func `Last Wager rewards a counterattack once across critical Gold and theft`() throws {
        let fixtures = UniqueCollectionTests()
        var profile = CombatantTalentCatalog.profile(for: ["wildcard_gold_t3_1"])
        let fortunateStrike = try #require(GameContent.itemAffixDefinition(matching: "lucky_clover"))
        fortunateStrike.basic.triggers.apply(to: &profile, abilityName: fortunateStrike.title)
        profile.triggers.criticalChanceBonus = 1
        var battle = try fixtures.battle(["the_knights_answer"], extra: profile, heroBasic: .blackjack)
        battle.roster.hero.currentHealth = 50
        battle.heroDeck = CombatDeck(abilities: [.slash, .block, .maul])
        let threshold = ControlMeterEngine.threshold(for: battle.enemy, in: battle)
        battle.insertEffect(
            .controlMeter(.stun, threshold - 1, threshold), to: battle.enemy,
            sourceID: battle.hero.id, remainingTurns: 0,
        )
        fixtures.block(5, owner: .hero, in: &battle)

        let hit = fixtures.enemyHit(1, in: &battle)

        #expect(battle.gold == 4)
        #expect(hit.events.count { $0.effectKind == .cardsDrawn && $0.abilityName == "Last Wager" } == 1)
        #expect(battle.hand.cards.map(\.ability.id) == [Ability.slash.id])

        battle.grantGoldEvent(1, to: battle.hero, abilityName: "Separate reward")
        #expect(battle.hand.cards.map(\.ability.id) == [Ability.slash.id, Ability.block.id])
    }
}
