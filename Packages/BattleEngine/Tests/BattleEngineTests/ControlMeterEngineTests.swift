import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class ControlMeterEngineTests: XCTestCase {
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
        let events = ControlMeterEngine.applyMeterCharge(
            15,
            keyword: .stun,
            to: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        XCTAssertTrue(events.contains { $0.effectKind == .preventionTriggered })
    }

    func testApplyBuildupNoDuplicateWhenSameKeywordSkipPending() {
        var context = makeContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
            ],
            seed: 0
        )
        let events = ControlMeterEngine.applyMeterCharge(
            15,
            keyword: .stun,
            to: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        XCTAssertTrue(events.isEmpty)
    }

    func testApplyBuildupAccumulatesOtherKeywordWhileSkipPending() {
        var context = makeContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
            ],
            seed: 0
        )
        let target = context.roster.enemy.combatant

        let events = ControlMeterEngine.applyMeterCharge(
            3,
            keyword: .freeze,
            to: target,
            sourceActorID: "source",
            in: &context
        )

        XCTAssertTrue(events.isEmpty)
        let freezeMeter = context.roster.activeEffects(for: target).first {
            guard case let .controlMeter(keyword, amount, _) = $0.effect else { return false }
            return keyword == .freeze && amount == 3
        }
        XCTAssertNotNil(freezeMeter)
        XCTAssertTrue(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
        XCTAssertFalse(context.roster.hasPendingActionSkip(for: target, keyword: .freeze))
    }

    func testStunAndFreezeMetersCoexistOnSameTarget() {
        let context = makeContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 4, 10), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .controlMeter(.freeze, 7, 10), remainingTicks: 0)
            ],
            seed: 0
        )
        let target = context.roster.enemy.combatant
        let meters = context.roster.activeEffects(for: target).compactMap(\.effect.controlMeterValues)
        XCTAssertEqual(meters.count, 2)
    }

    func testContextPreventionDelegatesToControlMeterEngine() {
        var contextContext = makeContext(seed: 0)
        var engineContext = makeContext(seed: 0)
        let target = contextContext.roster.enemy.combatant

        let contextEvents = contextContext.applyControlMeter(
            15, keyword: .stun, to: target, sourceActorID: "source"
        )
        let engineEvents = ControlMeterEngine.applyMeterCharge(
            15, keyword: .stun, to: target, sourceActorID: "source", in: &engineContext
        )

        XCTAssertEqual(
            contextEvents.map(\.effectKind),
            engineEvents.map(\.effectKind)
        )
    }
}
