import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct DamagePipelineTests {
    private let expectedStepNames = [
        "DodgeGate",
        "CriticalGate",
        "DamageBonus",
        "MarkedBonus",
        "ItemReduction",
        "CriticalMultiply",
        "Mitigation",
        "ShieldAbsorption",
        "TakeDamage",
        "MarkedConsume",
        "Hexmark",
        "DeathsDoor",
        "Leech",
        "ControlMeter",
        "ReactiveOnHit"
    ]

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

    @Test func executedStepNamesMatchCanonicalOrderForFullHit() throws {
        try #expect(DamagePipeline.canonicalNames == expectedStepNames)

        var context = makeContext(seed: 1772)
        let executed = DamagePipeline.executedStepNames(
            for: .directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source"
            ),
            in: &context
        )
        try #expect(executed == expectedStepNames)
        try #expect(executed == DamagePipeline.canonicalNames)
    }

    @Test func executedStepNamesShortCircuitAfterDodge() throws {
        let stats = PrimaryStats(agility: 280)
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

        let executed = DamagePipeline.executedStepNames(
            for: .directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source"
            ),
            in: &context
        )

        try #expect(executed == ["DodgeGate"], "High agility should dodge and short-circuit")
    }

    @Test func stepPhasesGroupStochasticResolutionAndPost() throws {
        let phases = DamagePipeline.steps.map(\.phase)
        try #expect(phases.filter { $0 == .stochastic }.count == 2)
        try #expect(phases.filter { $0 == .resolution }.count == 10)
        try #expect(phases.filter { $0 == .post }.count == 3)
        try #expect(DamagePipeline.steps.first?.phase == .stochastic)
        try #expect(DamagePipeline.steps.last?.phase == .post)
    }

    @Test func healthCostSkipsAttackPipelineSteps() throws {
        var context = makeContext(seed: 1772)
        let hero = context.roster.hero.combatant
        let executed = DamagePipeline.executedStepNames(
            for: DamageRequest(
                amount: 2,
                target: hero,
                keyword: .physical,
                sourceActorID: hero.id,
                options: .healthCost
            ),
            in: &context
        )
        try #expect(executed == ["TakeDamage", "DeathsDoor"])
    }

    @Test func healthCostIgnoresBlockBuffer() throws {
        var context = makeContext(seed: 1772)
        let hero = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTicks: 6)],
            for: hero
        )
        let healthBefore = context.roster.health(for: hero)

        let outcome = context.resolveDamage(
            DamageRequest(
                amount: 2,
                target: hero,
                keyword: .physical,
                sourceActorID: hero.id,
                options: .healthCost
            )
        )

        try #expect(outcome.healthLost == 2)
        try #expect(context.roster.health(for: hero) == healthBefore - 2)
        let shield = context.roster.activeEffects(for: hero).first {
            if case .shield = $0.effect {
                return true
            }
            return false
        }
        guard case let .shield(_, buffer) = shield?.effect else {
            Issue.record("Block should remain after a self health cost")
            return
        }
        try #expect(buffer == 20)
        try #expect(!(outcome.events.contains { $0.effectKind == .shieldAbsorbed }))
    }
}
