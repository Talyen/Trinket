import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct TrinketEffectTests {
    @Test func `loyal companion draws for companion on alternating turns`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionAbilities: [.slash],
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(companionCardsEveryOtherTurn: 1),
            )),
            dealOpeningHand: false,
        )
        for turn in 0 ... 3 {
            battle.turnCount = turn
            battle.hand = BattleHand()
            battle.companionDeck.putOnBottom(.slash)
            let events = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
            let drawn = events.filter { $0.effectKind == .cardsDrawn }.reduce(0) { $0 + $1.amount }
            #expect(drawn == (turn.isMultiple(of: 2) ? 1 : 0))
            #expect(battle.hand.cards.allSatisfy { $0.owner == .companion })
        }
    }
}
