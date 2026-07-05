import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class DamagePipelineTests: XCTestCase {
    private let expectedStepNames = [
        "DodgeGate",
        "CriticalGate",
        "DamageBonus",
        "MarkedBonus",
        "Mitigation",
        "ItemReduction",
        "ShieldAbsorption",
        "CriticalMultiply",
        "TakeDamage",
        "MarkedConsume",
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
            petModifiers: .zero
        )
    }

    func testRegistryCanonicalNamesMatchExpectedOrder() {
        XCTAssertEqual(DamagePipeline.canonicalNames, expectedStepNames)
    }

    func testExecutedStepNamesMatchCanonicalOrderForFullHit() {
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
        XCTAssertEqual(executed, expectedStepNames)
    }

    func testExecutedStepNamesShortCircuitAfterDodge() {
        let stats = PrimaryStats(agility: 140)
        let target = CombatantFixtures.combatant(
            id: "target", role: .enemy, maxHealth: 50, primaryStats: stats
        )
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            pet: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "pet", role: .pet)),
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
            petModifiers: .zero
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

        XCTAssertEqual(executed, ["DodgeGate"], "Seed 0 with high agility should dodge and short-circuit")
    }

    func testStepPhasesGroupStochasticResolutionAndPost() {
        let phases = DamagePipeline.steps.map(\.phase)
        XCTAssertEqual(phases.filter { $0 == .stochastic }.count, 2)
        XCTAssertEqual(phases.filter { $0 == .resolution }.count, 8)
        XCTAssertEqual(phases.filter { $0 == .post }.count, 3)
        XCTAssertEqual(DamagePipeline.steps.first?.phase, .stochastic)
        XCTAssertEqual(DamagePipeline.steps.last?.phase, .post)
    }
}
