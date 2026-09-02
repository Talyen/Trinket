import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct ControlStatusHandMaintenanceTests {
    @Test(arguments: [Keyword.freeze, Keyword.stun])
    func `control trigger purges owner cards and promotes surviving buffer`(keyword: Keyword) throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                abilities: [.slash, .heal, .smite],
            ),
            companion: CombatantFixtures.combatant(
                id: "companion",
                role: .companion,
                abilities: [.bash, .fangs],
            ),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
            dealOpeningHand: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.darkPact])
        battle.hand = BattleHand(
            cards: [
                BattleCard(id: 1, ability: .slash, owner: .hero),
                BattleCard(id: 2, ability: .bash, owner: .companion),
                BattleCard(id: 3, ability: .heal, owner: .hero),
            ],
            buffer: [
                BattleCard(id: 4, ability: .smite, owner: .hero),
                BattleCard(id: 5, ability: .fangs, owner: .companion),
            ],
        )

        let outcome = EffectHandlersTestSupport.dispatch(
            .controlMeter(keyword, 20, 10),
            ability: .slash,
            source: battle.enemy,
            target: battle.hero,
            battle: &battle,
        )

        try #expect(outcome.didApply)
        try #expect(battle.hand.cards.map(\.ability.id) == [Ability.bash.id, Ability.fangs.id])
        try #expect(battle.hand.buffer.isEmpty)
        try #expect(
            battle.heroDeck.abilities.map(\.id)
                == [Ability.darkPact.id, Ability.slash.id, Ability.heal.id, Ability.smite.id],
        )
        try #expect(outcome.events.contains { $0.effectKind == .controlTriggered && $0.keyword == keyword })
    }

    @Test func `promote next from buffer returns dead owner card to bottom of deck`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.slash]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: [.bash]),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
            dealOpeningHand: false,
        )
        battle.companionDeck = CombatDeck(abilities: [])
        battle.hand = BattleHand(
            cards: [
                BattleCard(id: 1, ability: .slash, owner: .hero),
            ],
            buffer: [
                BattleCard(id: 2, ability: .bash, owner: .companion),
                BattleCard(id: 3, ability: .slash, owner: .hero),
            ],
        )
        battle.roster.mutateRuntime(for: battle.companion) { $0.takeRawDamage(1000) }

        let promoted = battle.promoteNextTurnBufferCard(rebuildLog: false)

        #expect(promoted?.id == 3)
        #expect(battle.hand.cards.map(\.id) == [1, 3])
        #expect(battle.hand.buffer.isEmpty)
        #expect(battle.companionDeck.abilities.map(\.id) == [Ability.bash.id])
    }
}
