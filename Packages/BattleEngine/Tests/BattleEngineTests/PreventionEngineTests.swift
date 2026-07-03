import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class PreventionEngineTests: XCTestCase {
    private func makeContext(
        targetMaxHealth: Int = 50,
        targetEffects: [ActiveEffect] = [],
        seed: UInt64 = 0
    ) -> BattleEngineContext {
        let target = CombatantFixtures.combatant(
            id: "target", role: .enemy, maxHealth: targetMaxHealth
        )
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            pet: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "pet", role: .pet)),
            enemy: CombatantRuntime(combatant: target, initialActiveEffects: targetEffects)
        )
        return BattleEngineContext(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: seed),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            build: BattleCombatBuild(hero: source, pet: target, heroModifiers: .zero, petModifiers: .zero)
        )
    }

    func testApplyBuildupTriggersPreventionAtThreshold() {
        var context = makeContext(seed: 0)
        let events = PreventionEngine.applyBuildup(
            15,
            keyword: .stun,
            to: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        XCTAssertTrue(events.contains { $0.effectKind == .preventionTriggered })
    }

    func testApplyBuildupNoDuplicateWhenPreventionActive() {
        var context = makeContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .prevention(.stun, 2), remainingTicks: 2)
            ],
            seed: 0
        )
        let events = PreventionEngine.applyBuildup(
            15,
            keyword: .stun,
            to: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        XCTAssertTrue(events.isEmpty)
    }

    func testContextPreventionDelegatesToPreventionEngine() {
        var contextContext = makeContext(seed: 0)
        var engineContext = makeContext(seed: 0)
        let target = contextContext.roster.enemy.combatant

        let contextEvents = contextContext.applyPreventionBuildup(
            15, keyword: .stun, to: target, sourceActorID: "source"
        )
        let engineEvents = PreventionEngine.applyBuildup(
            15, keyword: .stun, to: target, sourceActorID: "source", in: &engineContext
        )

        XCTAssertEqual(
            contextEvents.map(\.effectKind),
            engineEvents.map(\.effectKind)
        )
    }
}
