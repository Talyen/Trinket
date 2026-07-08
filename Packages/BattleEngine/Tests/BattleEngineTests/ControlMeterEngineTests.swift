import Testing
import TrinketTestSupport
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct ControlMeterEngineTests {
    private func makeContext(
        targetMaxHealth: Int = 50,
        targetEffects: [ActiveEffect] = [],
        seed: UInt64 = 1772
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
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: .zero
        )
    }

    @Test func applyBuildupTriggersControlAtThreshold() {
        var context = makeContext(seed: 1772)
        let events = ControlMeterEngine.applyMeterCharge(
            15,
            keyword: .stun,
            to: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        #expect(events.contains { $0.effectKind == .controlTriggered })
    }

    @Test func applyBuildupNoDuplicateWhenSameKeywordSkipPending() {
        var context = makeContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
            ],
            seed: 1772
        )
        let events = ControlMeterEngine.applyMeterCharge(
            15,
            keyword: .stun,
            to: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        #expect(events.isEmpty)
    }

    @Test func applyBuildupAccumulatesOtherKeywordWhileSkipPending() throws {
        var context = makeContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
            ],
            seed: 1772
        )
        let target = context.roster.enemy.combatant

        let events = ControlMeterEngine.applyMeterCharge(
            3,
            keyword: .freeze,
            to: target,
            sourceActorID: "source",
            in: &context
        )

        #expect(events.isEmpty)
        let freezeMeter = context.roster.activeEffects(for: target).first {
            guard case let .controlMeter(keyword, amount, _) = $0.effect else { return false }
            return keyword == .freeze && amount == 3
        }
        _ = try #require(freezeMeter)
        #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
        #expect(!(context.roster.hasPendingActionSkip(for: target, keyword: .freeze)))
    }

    @Test func stunAndFreezeMetersCoexistOnSameTarget() {
        let context = makeContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 4, 10), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .controlMeter(.freeze, 7, 10), remainingTicks: 0)
            ],
            seed: 1772
        )
        let target = context.roster.enemy.combatant
        let meters = context.roster.activeEffects(for: target).compactMap(\.effect.controlMeterValues)
        #expect(meters.count == 2)
    }

    @Test func contextControlMeterDelegatesToControlMeterEngine() {
        var contextContext = makeContext(seed: 1772)
        var engineContext = makeContext(seed: 1772)
        let target = contextContext.roster.enemy.combatant

        let contextEvents = contextContext.applyControlMeter(
            15, keyword: .stun, to: target, sourceActorID: "source"
        )
        let engineEvents = ControlMeterEngine.applyMeterCharge(
            15, keyword: .stun, to: target, sourceActorID: "source", in: &engineContext
        )

        #expect(
            contextEvents.map(\.effectKind) == engineEvents.map(\.effectKind)
        )
    }

    @Test func overflowChargeIsConsumedOnTrigger() {
        var context = makeContext(targetMaxHealth: 100, seed: 1772)
        let target = context.roster.enemy.combatant

        let events = ControlMeterEngine.applyMeterCharge(
            50,
            keyword: .stun,
            to: target,
            sourceActorID: "source",
            in: &context
        )

        #expect(events.contains { $0.effectKind == .controlTriggered })
        #expect(
            context.roster.activeEffects(for: target).first {
                guard case let .controlMeter(_, amount, threshold) = $0.effect else { return false }
                return amount < threshold
            } != nil,
            "Partial build-up should be consumed on trigger"
        )
        #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
    }
}
