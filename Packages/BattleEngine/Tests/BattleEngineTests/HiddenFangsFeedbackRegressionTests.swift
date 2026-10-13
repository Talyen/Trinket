import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HiddenFangsFeedbackRegressionTests {
    @Test func `mimic opening bleed reports its actual health damage once`() throws {
        let mimic = try #require(GameContent.enemy(matching: "mimic"))
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(), enemy: mimic.combatant,
            enemyModifiers: CombatBuildResolver.build(enemy: mimic).modifiers, appliesFightPacing: false,
        )
        let initialHealth = battle.health(of: battle.hero)
        let events = battle.performTestAction(.fangs, from: .enemy, to: .hero)
        let direct = events.filter { $0.kind == .abilityDamage && $0.actorID == battle.enemy.id }
            .reduce(0) { $0 + $1.amount }
        let bonus = events.filter { $0.kind == .status && $0.abilityName == "Hidden Fangs" }
        #expect(bonus.count == 1)
        #expect(bonus.first?.amount == 2)
        #expect(initialHealth - battle.health(of: battle.hero) == direct + bonus.reduce(0) { $0 + $1.amount })
        #expect(BattleLogProjection.entries(from: events).contains { $0.text == "Hero takes 2 Bleed damage." })
        let next = battle.performTestAction(.fangs, from: .enemy, to: .hero)
        #expect(!next.contains { $0.abilityName == "Hidden Fangs" })
    }
}
