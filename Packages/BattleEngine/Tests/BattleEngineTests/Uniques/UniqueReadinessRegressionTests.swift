import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test func `Patient Edge waits through Knights Answer and a support card for the next manual hit`() throws {
        var context = try battle(["the_patient_edge", "the_knights_answer"], heroBasic: attack())
        block(10, owner: .hero, in: &context)
        let counter = enemyHit(5, in: &context)
        let hit = try #require(counter.events.first { $0.kind == .abilityDamage && $0.actorID == context.hero.id })
        #expect(!hit.isCritical)
        #expect(context.uniques.owners[.hero]?.patientEdgeReady == true)
        #expect(context.effectSummaries(of: context.hero).contains { $0.text.contains("The Patient Edge") })
        try play(.block, in: &context)
        #expect(context.uniques.owners[.hero]?.patientEdgeReady == true)
        let manual = try play(attack(), in: &context)
        #expect(manual.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(context.uniques.owners[.hero]?.patientEdgeReady == false)
    }

    @Test func `Vipers described readiness waits for manual Health damage`() throws {
        var context = try battle(["vipers_courtesy"])
        _ = CombatExecutor.run { await UniqueCombatEngine.afterUniqueDodge(
            by: context.hero, attackerID: context.enemy.id, in: &context,
        ) }
        _ = BattleTurnEngine.performAction(
            ability: attack(), actor: context.hero, abilityTarget: context.enemy, origin: .counterattack, context: &context,
        )
        #expect(context.uniques.owners[.hero]?.viperReady == true)
        block(20, owner: .enemy, in: &context)
        try play(attack(), in: &context)
        #expect(context.uniques.owners[.hero]?.viperReady == true)
        block(0, owner: .enemy, in: &context)
        try play(attack(), in: &context)
        #expect(context.uniques.owners[.hero]?.viperReady == false)
        #expect(context.roster.hasAffliction(.poison, on: context.enemy))
        #expect(context.roster.hasAffliction(.bleed, on: context.enemy))
    }
}
