import Testing
import TrinketContent
@testable import BattleEngine

struct RimewindRegressionTests {
    @Test func `Ray of Frost gives each damaging hit a Rimewind draw chance`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["frost_whelp_freeze_t1_1"])
        profile.triggers.freezeAttackDrawChancePercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionAbilities: [.rayOfFrost], enemyMaxHealth: 100,
            companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.companionDeck = CombatDeck(abilities: [.iceShot, .stargaze])
        battle.nextCardID += 1
        let card = BattleCard(id: battle.nextCardID, ability: .rayOfFrost, owner: .companion)
        battle.hand.append(card)

        let events = try battle.playCard(cardID: card.id)

        #expect(events.count { $0.effectKind == .cardsDrawn && $0.abilityName == "Rimewind" } == 2)
        #expect(battle.hand.cards.count == 2)
    }
}
