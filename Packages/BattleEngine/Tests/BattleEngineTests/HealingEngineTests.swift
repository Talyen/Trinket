import Testing
import TrinketTestSupport
@testable import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct HealingEngineTests {
    private func makeContext(seed: UInt64 = 1772) -> BattleEngineContext {
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
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
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: .zero
        )
    }

    @Test func resolveHealSilentEmitsNoEvents() throws {
        var context = makeContext(seed: 1772)
        _ = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        let outcome = HealingEngine.resolveHeal(
            HealRequest(amount: 5, target: context.roster.enemy.combatant, logAs: .silent),
            in: &context
        )
        try #expect(outcome.healthRestored > 0)
        try #expect(outcome.events.isEmpty)
    }

    @Test func resolveHealInstantHealPolicyEmitsEvent() throws {
        var context = makeContext(seed: 1772)
        let target = context.roster.enemy.combatant
        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: 3,
                target: target,
                sourceActorID: "source",
                logAs: .instantHeal(
                    actorName: "Hero",
                    abilityName: "Heal",
                    keyword: .health,
                    displayAmount: 3
                )
            ),
            in: &context
        )
        try #expect(outcome.events.count == 1)
        try #expect(outcome.events.first?.effectKind == .instantHeal)
        try #expect(outcome.events.first?.amount == outcome.healthRestored)
    }

    @Test func leechFromDamageHealsAndSetsLeechedFlag() throws {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let outcome = HealingEngine.leechFromDamage(10, sourceActorID: "source", in: &context)
        try #expect(outcome.flags.contains(.leeched))
        try #expect(context.roster.hero.currentHealth > before)
        try #expect(outcome.healthRestored == context.roster.hero.currentHealth - before)
        try #expect(outcome.events.first?.amount == outcome.healthRestored)
    }

    @Test func leechFromDamageDoesNotReviveDefeatedSource() throws {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 0 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let outcome = HealingEngine.leechFromDamage(10, sourceActorID: "source", in: &context)
        try #expect(outcome.healthRestored == 0)
        try #expect(context.roster.hero.currentHealth == 0)
    }

    @Test func resolveHealIgnoresDefeatedTarget() throws {
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.enemy.combatant) { $0.currentHealth = 0 }
        let outcome = HealingEngine.resolveHeal(
            HealRequest(amount: 5, target: context.roster.enemy.combatant, logAs: .silent),
            in: &context
        )
        try #expect(outcome.healthRestored == 0)
        try #expect(context.roster.enemy.currentHealth == 0)
    }

    @Test func healFromOneHPWhileDeathsDoorActive() throws {
        var context = makeContext(seed: 1772)
        let hero = context.roster.hero.combatant
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 1 }
        context.prependEffect(.deathsDoor, to: hero, remainingTicks: BattleTiming.deathsDoorDurationTicks)

        let outcome = HealingEngine.resolveHeal(
            HealRequest(amount: 10, target: hero, logAs: .silent),
            in: &context
        )

        try #expect(outcome.healthRestored > 0)
        try #expect(context.roster.health(for: hero) > 1)
        try #expect(context.roster.isDeathsDoorActive(for: hero))
    }

    @Test func healDoesNotRemoveDeathsDoorEffect() throws {
        var context = makeContext(seed: 1772)
        let hero = context.roster.hero.combatant
        context.roster.mutateRuntime(for: hero) {
            $0.currentHealth = 1
            $0.hasConsumedDeathsDoor = true
        }
        context.prependEffect(.deathsDoor, to: hero, remainingTicks: BattleTiming.deathsDoorDurationTicks)

        _ = HealingEngine.resolveHeal(
            HealRequest(amount: 20, target: hero, logAs: .silent),
            in: &context
        )

        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
    }

    @Test func contextResolveHealDelegatesToHealingEngine() throws {
        var context = makeContext(seed: 1772)
        let contextOutcome = context.resolveHeal(
            HealRequest(amount: 5, target: context.roster.enemy.combatant)
        )
        var fresh = makeContext(seed: 1772)
        let engineOutcome = HealingEngine.resolveHeal(
            HealRequest(amount: 5, target: fresh.roster.enemy.combatant),
            in: &fresh
        )
        try #expect(contextOutcome.healthRestored == engineOutcome.healthRestored)
    }
}
