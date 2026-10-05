import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DodgeCardChainRegressionTests {
    @Test func `dance of blades repeats after the drawn attack Critically Hits`() throws {
        let item = try #require(GameContent.unique(matching: "dance_of_blades"))
        let power = try #require(item.resolvedPower(at: 0))
        var profile = CombatModifierProfile.zero
        power.triggers.apply(to: &profile)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        battle.heroDeck = CombatDeck(abilities: [.stab, .block])

        let events = CombatExecutor.run { await CombatTriggerEngine.afterDodge(
            by: battle.hero, attackerID: battle.enemy.id, in: &battle,
        ) }

        #expect(events.contains { $0.kind == .abilityDamage && $0.abilityID == Ability.stab.id && $0.isCritical })
        #expect(battle.heroDeck.abilities.isEmpty)
    }

    @Test func `dance of blades does not repeat for critical Leech on a noncritical attack`() throws {
        let item = try #require(GameContent.unique(matching: "dance_of_blades"))
        let power = try #require(item.resolvedPower(at: 0))
        var profile = CombatModifierProfile.zero
        power.triggers.apply(to: &profile)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10,
            heroModifiers: profile,
            rngSeed: 17,
        )
        battle.appliesFightPacing = false
        battle.heroDeck = CombatDeck(abilities: [.fangs, .block])

        let events = CombatExecutor.run { await CombatTriggerEngine.afterDodge(
            by: battle.hero, attackerID: battle.enemy.id, in: &battle,
        ) }

        #expect(events.contains { $0.keyword == .leech && $0.isCritical })
        #expect(events.contains { $0.kind == .abilityDamage && $0.abilityID == Ability.fangs.id && !$0.isCritical })
        #expect(battle.heroDeck.abilities.map(\.id) == [Ability.block.id])
        #expect(battle.turnCadence.cardsPlayed[.hero] == 1)
    }
}
