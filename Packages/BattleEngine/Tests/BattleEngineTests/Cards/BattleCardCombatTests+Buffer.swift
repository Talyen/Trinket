import Testing
import TrinketContent
@testable import BattleEngine

extension BattleCardCombatTests {
    @Test(arguments: [false, true])
    func `recording a transition does not change combat or randomness`(opening: Bool) throws {
        var plain = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash, .darkPact, .shadowstep],
            companionAbilities: [.block, .heal, .luckPotion],
            enemyMaxHealth: 200,
            dealOpeningHand: false,
        )
        if !opening {
            _ = plain.drawOpeningHand()
            let card = try #require(plain.hand.cards.first)
            _ = try plain.playCard(cardID: card.id)
        }
        var recorded = plain
        var checkpoints: [BattleTransitionCheckpoint] = []
        var hands: [BattleHand] = []
        let record: (BattleTransitionCheckpoint, BattleState, [ActionEvent]) -> Void = { checkpoint, state, _ in
            checkpoints.append(checkpoint)
            hands.append(state.hand)
        }
        let plainEvents = opening ? plain.drawOpeningHand() : plain.endTurn()
        let recordedEvents = opening ? recorded.drawOpeningHand(recording: record) : recorded.endTurn(recording: record)
        #expect(checkpoints.last == .ready)
        #expect(hands.last == recorded.hand)
        #expect(plain.hand == recorded.hand)
        for owner in [BattleParticipant.hero, .companion, .enemy] {
            #expect(plain.roster[owner] == recorded.roster[owner])
        }
        #expect(plain.goldFlow == recorded.goldFlow)
        #expect(plain.phase == recorded.phase)
        #expect(plainEvents == recordedEvents)
        #expect(plain.rng.next() == recorded.rng.next())
    }

    @Test func `draw effects preserve the older buffered cards place in hand`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.apple, .darkPact, .shadowstep],
            companionAbilities: [.block, .heal, .luckPotion],
            dealOpeningHand: false,
        )
        let waiting = BattleCard(id: 4, ability: .heal, owner: .companion)
        battle.hand = BattleHand(
            cards: [
                BattleCard(id: 1, ability: .darkPact, owner: .hero),
                BattleCard(id: 2, ability: .shadowstep, owner: .hero),
                BattleCard(id: 3, ability: .block, owner: .companion),
            ],
            buffer: [waiting],
        )
        battle.nextCardID = 4
        battle.heroDeck = CombatDeck(abilities: [.apple])
        battle.companionDeck = CombatDeck(abilities: [.luckPotion])

        _ = try battle.playCard(cardID: 1)

        #expect(battle.hand.cards.map(\.id) == [2, 3, waiting.id])
        #expect(battle.hand.buffer.map(\.ability.id) == [Ability.apple.id])
        #expect(battle.heroDeck.abilities.map(\.id) == [Ability.darkPact.id])
    }
}
