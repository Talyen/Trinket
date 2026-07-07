import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct DoTDamageTests {
    private func makeContext(
        sourceStats: PrimaryStats = PrimaryStats(),
        heroModifiers: CombatModifierProfile = .zero,
        seed: UInt64 = 1772
    ) -> BattleEngineContext {
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 100)
        let source = CombatantFixtures.combatant(
            id: "source", role: .hero, maxHealth: 50, primaryStats: sourceStats
        )
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            pet: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "pet", role: .pet)),
            enemy: CombatantRuntime(combatant: target, initialActiveEffects: [])
        )
        return BattleEngineContext(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: seed),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: heroModifiers,
            petModifiers: .zero,
            enemyModifiers: .zero
        )
    }

    @Test func resolveTickStoresBasePotencyOnStack() {
        var context = makeContext()
        _ = DoTApplicator.applyDecayingDoT(
            keyword: .burn,
            potency: 4,
            to: context.roster.enemy.combatant,
            sourceActorID: "source",
            dealImmediateDamage: false,
            in: &context
        )
        let potency = context.roster.enemy.activeEffects.first { $0.keyword == .burn }?.effect.potency
        #expect(potency == 4)
    }

    @Test func resolveTickAppliesStatBonusAtDamageTime() {
        let stats = PrimaryStats(intellect: 20) // +4 burn
        var context = makeContext(sourceStats: stats)
        let outcome = DoTDamage.resolveTick(
            basePotency: 4,
            keyword: .burn,
            target: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        #expect(outcome.healthLost == 8)
        #expect(outcome.events.contains { $0.kind == .status && $0.amount == 8 })
    }

    @Test func resolveTickAppliesItemDamageDealtBonus() {
        var modifiers = CombatModifierProfile.zero
        modifiers.damageDealtBonus[.burn] = 3
        var context = makeContext(heroModifiers: modifiers)
        let outcome = DoTDamage.resolveTick(
            basePotency: 4,
            keyword: .burn,
            target: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        #expect(outcome.healthLost == 7)
    }

    @Test func resolveTickIncludesStatusEventWhenDamageDealt() {
        var context = makeContext()
        let outcome = DoTDamage.resolveTick(
            basePotency: 5,
            keyword: .burn,
            target: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        #expect(outcome.events.contains { $0.kind == .status && $0.keyword == .burn })
    }
}
