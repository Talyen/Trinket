import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct HealingEngineTests {
    private func makeContext(seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed) -> BattleState {
        BattleTestFixtures.makePipelineContext(seed: seed)
    }

    @Test(arguments: [true, false])
    func resolveHealEmitsEventsOnlyForInstantHealPolicy(emitsEvent: Bool) throws {
        var context = makeContext(seed: 1772)
        if !emitsEvent {
            _ = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        }
        let target = context.roster.enemy.combatant
        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: emitsEvent ? 3 : 5,
                target: target,
                sourceActorID: emitsEvent ? "source" : nil,
                logAs: emitsEvent
                    ? .instantHeal(
                        actorName: "Hero",
                        abilityName: "Heal",
                        keyword: .health,
                        displayAmount: 3
                    )
                    : .silent
            ),
            in: &context
        )
        if emitsEvent {
            try #expect(outcome.events.count == 1)
            try #expect(outcome.events.first?.effectKind == .instantHeal)
            try #expect(outcome.events.first?.amount == outcome.healthRestored)
        } else {
            try #expect(outcome.healthRestored > 0)
            try #expect(outcome.events.isEmpty)
        }
    }

    @Test func leechFromDamageHealsAndSetsLeechedFlag() throws {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTurns: 3)
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

    @Test func abilityLeechHealsHalfOfDamageDealt() throws {
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        let before = context.roster.hero.currentHealth
        let outcome = HealingEngine.leechFromDamage(
            10,
            sourceActorID: "source",
            abilityHasLeech: true,
            in: &context
        )
        try #expect(outcome.flags.contains(.leeched))
        try #expect(outcome.healthRestored == 5)
        try #expect(context.roster.hero.currentHealth == before + 5)
    }

    @Test func leechFromDamageDoesNotReviveDefeatedSource() throws {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTurns: 3)
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
        context.prependEffect(.deathsDoor, to: hero, remainingTurns: BattleTiming.deathsDoorDurationTurns)

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
        context.prependEffect(.deathsDoor, to: hero, remainingTurns: BattleTiming.deathsDoorDurationTurns)

        _ = HealingEngine.resolveHeal(
            HealRequest(amount: 20, target: hero, logAs: .silent),
            in: &context
        )

        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
    }

    @Test func instantHealCanCriticalWithWisdom() throws {
        let source = CombatantFixtures.combatant(
            id: "source",
            role: .hero,
            maxHealth: 50,
            primaryStats: PrimaryStats(wisdom: 20)
        )
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            companion: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "companion", role: .companion)),
            enemy: CombatantRuntime(combatant: target, initialActiveEffects: [])
        )
        var context = BattleState(
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
        context.roster.mutateRuntime(for: target) { $0.currentHealth = 10 }

        // Force crit via active critical-chance buff.
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .criticalChanceBonus(1.0, 6), remainingTurns: 6)],
            for: source
        )

        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: 5,
                target: target,
                sourceActorID: "source",
                logAs: .instantHeal(
                    actorName: "Hero",
                    abilityName: "Heal",
                    keyword: .health,
                    displayAmount: 5
                )
            ),
            in: &context
        )

        try #expect(outcome.isCritical)
        try #expect(outcome.healthRestored == 10)
        try #expect(outcome.events.first?.isCritical == true)
        try #expect(outcome.events.first?.amount == 10)
    }

    @Test func leechHealCanCriticalWithWisdom() throws {
        var context = BattleTestFixtures.makePipelineContext(
            sourcePrimaryStats: PrimaryStats(wisdom: 20),
            seed: 1772
        )
        let source = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [
                ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTurns: 3),
                ActiveEffect(id: 2, effect: .criticalChanceBonus(1.0, 6), remainingTurns: 6),
            ],
            for: source
        )
        context.roster.mutateRuntime(for: source) { $0.currentHealth = 20 }

        let outcome = HealingEngine.leechFromDamage(10, sourceActorID: "source", in: &context)
        try #expect(outcome.isCritical)
        try #expect(outcome.flags.contains(.leeched))
        // Crit doubles the 10 leech heal to 20; target Wisdom 20 adds +4 via heal().
        try #expect(outcome.healthRestored == 24)
        try #expect(outcome.events.first?.isCritical == true)
        try #expect(outcome.events.first?.keyword == .leech)
    }

    @Test func silentHealsDoNotRollCritical() throws {
        var context = makeContext(seed: 1)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 10 }
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .criticalChanceBonus(1.0, 6), remainingTurns: 6)],
            for: context.roster.hero.combatant
        )
        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: 5,
                target: context.roster.hero.combatant,
                sourceActorID: "source",
                logAs: .silent
            ),
            in: &context
        )
        try #expect(!outcome.isCritical)
        try #expect(outcome.healthRestored == 5)
    }
}
