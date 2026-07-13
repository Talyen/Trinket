import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

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
            companion: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "companion", role: .companion)),
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
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
    }

    @Test func applyBuildupTriggersControlAtThreshold() throws {
        var context = makeContext(seed: 1772)
        let events = ControlMeterEngine.applyMeterCharge(
            15,
            keyword: .stun,
            to: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        try #expect(events.contains { $0.effectKind == .controlTriggered })
    }

    @Test func applyBuildupNoDuplicateWhenSameKeywordSkipPending() throws {
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
        try #expect(events.isEmpty)
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

        try #expect(events.isEmpty)
        let freezeMeter = context.roster.activeEffects(for: target).first {
            guard case let .controlMeter(keyword, amount, _) = $0.effect else { return false }
            return keyword == .freeze && amount == 3
        }
        _ = try #require(freezeMeter)
        try #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
        try #expect(!(context.roster.hasPendingActionSkip(for: target, keyword: .freeze)))
    }

    @Test func stunAndFreezeMetersCoexistOnSameTarget() throws {
        let context = makeContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 4, 10), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .controlMeter(.freeze, 7, 10), remainingTicks: 0)
            ],
            seed: 1772
        )
        let target = context.roster.enemy.combatant
        let meters = context.roster.activeEffects(for: target).compactMap(\.effect.controlMeterValues)
        try #expect(meters.count == 2)
    }

    @Test func overflowChargeIsConsumedOnTrigger() throws {
        var context = makeContext(targetMaxHealth: 100, seed: 1772)
        let target = context.roster.enemy.combatant

        let events = ControlMeterEngine.applyMeterCharge(
            50,
            keyword: .stun,
            to: target,
            sourceActorID: "source",
            in: &context
        )

        try #expect(events.contains { $0.effectKind == .controlTriggered })
        try #expect(
            !context.roster.activeEffects(for: target).contains {
                guard case let .controlMeter(_, amount, threshold) = $0.effect else { return false }
                return amount < threshold
            },
            "Partial build-up should be consumed on trigger"
        )
        try #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
    }
}
