import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct ControlStatusCardDrawTests {
    @Test(arguments: [Keyword.freeze, Keyword.stun])
    func `opening hand does not backfill pending control owner`(keyword: Keyword) throws {
        let battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                abilities: [.slash, .heal, .smite],
            ),
            companion: CombatantFixtures.combatant(
                id: "companion",
                role: .companion,
                abilities: [.bash, .fangs, .bloodthorn],
            ),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(keyword, 10, 10), remainingTurns: 0),
            ],
        )

        try #expect(battle.hand.count == 2)
        try #expect(battle.hand.cards.allSatisfy { $0.owner == .companion })
        try #expect(battle.heroDeck.count == battle.hero.abilityLoadout.abilities.count)
    }

    @Test(arguments: [Keyword.freeze, Keyword.stun])
    func `pending control blocks deck draws but linger does not`(keyword: Keyword) throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                abilities: [.slash, .heal, .smite],
            ),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
        )
        battle.hand = BattleHand()
        battle.heroDeck = CombatDeck(abilities: [.slash, .heal, .smite])
        battle.withEngineContext { context in
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(keyword, 10, 10), remainingTurns: 0)],
                for: context.hero,
            )
        }

        let deckBefore = battle.heroDeck
        try #expect(BattleCardCombatEngine.drawCards(count: 2, for: .hero, context: &battle) == 0)
        try #expect(
            BattleCardCombatEngine.drawFirstCard(matching: .physical, for: .hero, context: &battle) == nil,
        )
        try #expect(battle.heroDeck == deckBefore)
        try #expect(battle.hand.cards.allSatisfy { $0.owner != .hero })

        battle.withEngineContext { context in
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(keyword, 10, 10), remainingTurns: 1)],
                for: context.hero,
            )
        }
        try #expect(BattleCardCombatEngine.drawCards(count: 1, for: .hero, context: &battle) == 1)
    }
}
