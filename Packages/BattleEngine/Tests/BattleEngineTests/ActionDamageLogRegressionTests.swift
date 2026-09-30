import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ActionDamageLogRegressionTests {
    @Test func `blood offering logs its health cost separately from enemy damage`() throws {
        var battle = makeBattle()
        let before = battle.health(of: battle.hero)
        let events = BattleTurnEngine.performAction(
            ability: .bloodOffering, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(before - battle.health(of: battle.hero) == 2)
        let summary = try #require(events.last { $0.kind == .ability })
        let entries = BattleLogReducer.entries(from: events)
        let line = try #require(entries.first { $0.id == events.firstIndex(of: summary) })
        #expect(line.text.contains("1 Bleed damage to Enemy"))
        #expect(line.text.contains("loses 2 Health"))
        #expect(!line.text.contains("3 Bleed damage to Enemy"))
        var projection = BattleLogProjection()
        projection.sync(events: Array(events.dropLast()))
        projection.sync(events: events)
        #expect(projection.entries == entries)
    }

    @Test func `bloodthorn logs both damage types`() throws {
        var battle = makeBattle()
        let events = BattleTurnEngine.performAction(
            ability: .bloodthorn, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        let summary = try #require(events.last { $0.kind == .ability })
        let line = try #require(BattleLogReducer.entries(from: events).first { $0.id == events.firstIndex(of: summary) })
        #expect(line.text.contains("2 Bleed damage to Enemy"))
        #expect(line.text.contains("2 Poison damage to Enemy"))
        #expect(!line.text.contains("4 Bleed damage"))
    }

    private func makeBattle() -> BattleState {
        let profile = CombatModifierProfile(triggers: CombatTraitTriggers(damage: DamageTriggers(criticalChanceBonus: -1)))
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.bloodOffering, .bloodthorn], heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        return battle
    }
}
