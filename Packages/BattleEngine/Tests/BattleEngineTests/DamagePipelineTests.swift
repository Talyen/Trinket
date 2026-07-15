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

    @Test func registryCanonicalNamesMatchExpectedOrder() throws {
        try #expect(DamagePipeline.canonicalNames == expectedStepNames)
    }

    @Test func executedStepNamesMatchCanonicalOrderForFullHit() throws {
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
    }

    @Test func executedStepNamesShortCircuitAfterDodge() throws {
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

        let executed = DamagePipeline.executedStepNames(
            for: .directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source"
            ),
            in: &context
        )

        try #expect(executed == ["DodgeGate"], "Seed 0 with high agility should dodge and short-circuit")
    }

    @Test func stepPhasesGroupStochasticResolutionAndPost() throws {
        let phases = DamagePipeline.steps.map(\.phase)
        try #expect(phases.filter { $0 == .stochastic }.count == 2)
        try #expect(phases.filter { $0 == .resolution }.count == 10)
        try #expect(phases.filter { $0 == .post }.count == 3)
        try #expect(DamagePipeline.steps.first?.phase == .stochastic)
        try #expect(DamagePipeline.steps.last?.phase == .post)
    }
}
