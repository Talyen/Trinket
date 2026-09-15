import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `golden opportunity limits multiple gains and empty decks`() {
        var battle = heroTalentBattle("fox_gold_t2_1")
        battle.heroDeck = CombatDeck(abilities: [.slash, .stab, .bash])
        for amount in [4, 5, 10] {
            let events = battle.grantGoldEvent(amount, to: battle.hero, abilityName: "Gold")
            #expect(events.contains { $0.effectKind == .cardsDrawn } == (amount == 5))
        }
        battle.turnCount += 1
        let renewed = battle.grantGoldEvent(5, to: battle.hero, abilityName: "Gold")
        #expect(renewed.contains { $0.effectKind == .cardsDrawn })
        battle.turnCount += 1
        battle.heroDeck = CombatDeck(abilities: [])
        _ = battle.grantGoldEvent(5, to: battle.hero, abilityName: "Gold")
        battle.heroDeck = CombatDeck(abilities: [.slash])
        let spent = battle.grantGoldEvent(5, to: battle.hero, abilityName: "Gold")
        #expect(!spent.contains { $0.effectKind == .cardsDrawn })
    }
}
