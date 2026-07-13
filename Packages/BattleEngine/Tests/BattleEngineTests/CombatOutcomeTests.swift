import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct CombatOutcomeTests {
    private func makeContext(seed: UInt64 = 1772) -> BattleEngineContext {
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            companion: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "companion", role: .companion)),
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
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
    }

    @Test func resolveDamageReturnsCombatOutcome() throws {
        var context = makeContext(seed: 1772)
        let outcome = context.resolveDamage(
            .directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source"
            )
        )
        try #expect(outcome.healthLost == 10)
        try #expect(outcome.healthDelta == -10)
        try #expect(context.roster.enemy.currentHealth == 40)
    }

    @Test func resolveDamageSetsDodgedFlag() throws {
        let stats = PrimaryStats(agility: 140)
        let target = CombatantFixtures.combatant(
            id: "target", role: .enemy, maxHealth: 50, primaryStats: stats
        )
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            companion: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "companion", role: .companion)),
            enemy: CombatantRuntime(combatant: target, initialActiveEffects: [])
        )
        var context = BattleEngineContext(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
        let outcome = context.resolveDamage(
            .directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source"
            )
        )
        if outcome.healthLost == 0 {
            try #expect(outcome.flags.contains(.dodged))
        }
    }

    @Test func resolveDamageSetsLeechedFlag() throws {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let outcome = context.resolveDamage(
            .directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source"
            )
        )
        try #expect(outcome.flags.contains(.leeched))
        try #expect(outcome.events.contains { $0.effectKind == .leechHeal })
    }

    @Test func damageRequestDoTTickPresetAppliesBonusesWithoutDodge() throws {
        let preset = DamageRequest.doTTick(
            amount: 10,
            target: CombatantFixtures.combatant(id: "t", role: .enemy),
            keyword: .burn,
            sourceActorID: "source"
        )
        try #expect(preset.options.applyStatBonus)
        try #expect(!(preset.options.applyDodge))
        try #expect(preset.options.applyItemBonus)
    }

    @Test func damageRequestDirectAbilityHitUsesDefaultOptions() throws {
        let preset = DamageRequest.directAbilityHit(
            amount: 5,
            target: CombatantFixtures.combatant(id: "t", role: .enemy),
            keyword: .physical,
            sourceActorID: "source"
        )
        try #expect(preset.options == .directAbilityHit)
    }

    @Test func resolveHealReturnsRestoredAmount() throws {
        var context = makeContext(seed: 1772)
        _ = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        let before = context.roster.enemy.currentHealth
        let outcome = context.resolveHeal(
            HealRequest(amount: 5, target: context.roster.enemy.combatant)
        )
        try #expect(outcome.healthRestored == context.roster.enemy.currentHealth - before)
        try #expect(outcome.healthRestored > 0)
        try #expect(outcome.healthDelta == outcome.healthRestored)
    }
}
