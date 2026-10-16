import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test func `Patient Edge waits through Knights Answer and a support card for the next manual hit`() throws {
        var context = try battle(["the_patient_edge", "the_knights_answer"], heroBasic: attack())
        block(10, owner: .hero, in: &context)
        let counter = context.recordingResult { observation in enemyHit(5, in: &observation) }
        let hit = try #require(counter.events.first { $0.kind == .abilityDamage && $0.actorID == context.hero.id })
        #expect(!hit.isCritical)
        #expect(context.roster[.hero].uniques.patientEdgeReady == true)
        #expect(context.effectSummaries(of: context.hero).contains { $0.text.contains("The Patient Edge") })
        try play(.block, in: &context)
        #expect(context.roster[.hero].uniques.patientEdgeReady == true)
        let manual = try play(attack(), in: &context)
        #expect(manual.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(context.roster[.hero].uniques.patientEdgeReady == false)
    }

    @Test func `Vipers described readiness waits for manual Health damage`() throws {
        var context = try battle(["vipers_courtesy"])
        CombatExecutor.run { await UniqueCombatEngine.afterUniqueDodge(
            by: context.hero, attackerID: context.enemy.id, in: &context,
        ) }
        BattleTurnEngine.performAction(
            ability: attack(), actor: context.hero, abilityTarget: context.enemy, origin: .counterattack, context: &context,
        )
        #expect(context.roster[.hero].uniques.viperReady == true)
        block(20, owner: .enemy, in: &context)
        try play(attack(), in: &context)
        #expect(context.roster[.hero].uniques.viperReady == true)
        block(0, owner: .enemy, in: &context)
        try play(attack(), in: &context)
        #expect(context.roster[.hero].uniques.viperReady == false)
        #expect(context.roster.hasAffliction(.poison, on: context.enemy))
        #expect(context.roster.hasAffliction(.bleed, on: context.enemy))
    }

    @Test func `restoring a combatant runtime restores its prepared attacks without changing its snapshot`() throws {
        var context = try battle(["the_patient_edge"])
        block(10, owner: .hero, in: &context)
        _ = enemyHit(5, in: &context)
        context.roster.mutateRuntime(for: context.hero) {
            $0.talents.history.preparations.insert(.doublePoison)
        }
        let prepared = context.roster.hero

        let firstPhysical = try play(attack(), in: &context)
        let firstPoison = try play(attack(.poison), in: &context)
        #expect(firstPhysical.contains { $0.kind == .abilityDamage && $0.isCritical })
        let firstPoisonDamage = try #require(firstPoison.first {
            $0.kind == .abilityDamage && $0.keyword == .poison
        }?.amount)
        #expect(!context.effectSummaries(of: context.hero).contains { $0.text.contains("Unstable Culture") })
        #expect(context.roster.hero != prepared)

        context.roster.update(prepared)
        #expect(context.effectSummaries(of: context.hero).contains { $0.text.contains("The Patient Edge") })
        #expect(context.effectSummaries(of: context.hero).contains { $0.text.contains("Unstable Culture") })
        let restoredPhysical = try play(attack(), in: &context)
        let restoredPoison = try play(attack(.poison), in: &context)
        #expect(restoredPhysical.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(restoredPoison.first { $0.kind == .abilityDamage && $0.keyword == .poison }?.amount == firstPoisonDamage)
        #expect(prepared.uniques.patientEdgeReady)
        #expect(prepared.talents.history.preparations.contains(.doublePoison))
    }
}
