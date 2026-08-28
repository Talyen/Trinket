import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct ControlMeterEngineTests {
    @Test func applyBuildupTriggersControlAtThreshold() throws {
        var context = BattleTestFixtures.makePipelineContext()
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
        var context = BattleTestFixtures.makePipelineContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
            ]
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

    @Test func applyBuildupNoDuplicateDuringControlStatusLinger() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetEffects: [
                ActiveEffect(
                    id: 1,
                    effect: .controlMeter(.stun, 10, 10),
                    remainingTurns: BattleTiming.controlStatusLingerTurns
                ),
            ]
        )
        let target = context.roster.enemy.combatant
        try #expect(!(context.roster.hasPendingActionSkip(for: target, keyword: .stun)))
        try #expect(context.roster.hasControlStatus(for: target, keyword: .stun))

        let events = ControlMeterEngine.applyMeterCharge(
            15,
            keyword: .stun,
            to: target,
            sourceActorID: "source",
            in: &context
        )
        try #expect(events.isEmpty)
    }

    @Test func applyBuildupAccumulatesOtherKeywordWhileSkipPending() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
            ]
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
        let context = BattleTestFixtures.makePipelineContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 4, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .controlMeter(.freeze, 7, 10), remainingTurns: 0),
            ]
        )
        let target = context.roster.enemy.combatant
        let meters = context.roster.activeEffects(for: target).compactMap(\.effect.controlMeterValues)
        try #expect(meters.count == 2)
    }

    @Test func overflowChargeIsConsumedOnTrigger() throws {
        var context = BattleTestFixtures.makePipelineContext(targetMaxHealth: 100)
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

    @Test func reducedStunThresholdStillRegistersFullMeterAndSkip() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 100,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                control: ControlTriggers(enemyStunThresholdReductionPercent: 0.25)
            ))
        )
        let target = context.roster.enemy.combatant
        let baseThreshold = ControlMeterEngine.threshold(for: target, in: context)

        // Charge well past the reduced threshold; the cap clamps at "full".
        let events = ControlMeterEngine.applyMeterCharge(
            baseThreshold,
            keyword: .stun,
            to: target,
            sourceActorID: "source",
            in: &context
        )

        try #expect(events.contains { $0.effectKind == .controlTriggered })
        try #expect(context.roster.hasControlStatus(for: target, keyword: .stun))
        try #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
        let meter = try #require(
            context.roster.activeEffects(for: target)
                .first { $0.keyword == .stun }?
                .effect.controlMeterValues
        )
        try #expect(meter.threshold == baseThreshold, "stored basis stays canonical (base)")
        try #expect(meter.amount == baseThreshold, "a full meter reads as full against its stored basis")
    }

    @Test func stunExtendChanceZeroGrantsNoExtraSkip() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(stunExtendChancePercent: 0)
            )),
            seed: 0
        )
        let enemy = context.roster.enemy.combatant
        let threshold = ControlMeterEngine.threshold(for: enemy, in: context)
        _ = ControlMeterEngine.applyMeterCharge(
            threshold, keyword: .stun, to: enemy, sourceActorID: "source",
            applyFightPacing: false, in: &context
        )
        try #expect((context.additionalControlSkipsByCombatantID[enemy.id] ?? 0) == 0)
    }

    @Test func stunExtendChanceOneGuaranteesExtraSkip() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(stunExtendChancePercent: 1.0)
            )),
            seed: 0
        )
        let enemy = context.roster.enemy.combatant
        let threshold = ControlMeterEngine.threshold(for: enemy, in: context)
        _ = ControlMeterEngine.applyMeterCharge(
            threshold, keyword: .stun, to: enemy, sourceActorID: "source",
            applyFightPacing: false, in: &context
        )
        try #expect((context.additionalControlSkipsByCombatantID[enemy.id] ?? 0) == 1)
    }

    @Test func freezeExtendChanceRespectsSeed() throws {
        // Seed 0 hits at 0.20, seed 1 misses — validates chance path, not just 0/1 endpoints.
        var hitContext = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(freezeExtendChancePercent: 0.20)
            )),
            seed: 0
        )
        let hitEnemy = hitContext.roster.enemy.combatant
        _ = ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: hitEnemy, in: hitContext),
            keyword: .freeze, to: hitEnemy, sourceActorID: "source",
            applyFightPacing: false, in: &hitContext
        )
        try #expect((hitContext.additionalControlSkipsByCombatantID[hitEnemy.id] ?? 0) == 1)

        var missContext = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(freezeExtendChancePercent: 0.20)
            )),
            seed: 1
        )
        let missEnemy = missContext.roster.enemy.combatant
        _ = ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: missEnemy, in: missContext),
            keyword: .freeze, to: missEnemy, sourceActorID: "source",
            applyFightPacing: false, in: &missContext
        )
        try #expect((missContext.additionalControlSkipsByCombatantID[missEnemy.id] ?? 0) == 0)
    }

    @Test func legacyFreezeExtraActionSkipsMapsToTwentyPercent() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(freezeExtraActionSkips: 1)
            )),
            seed: 0
        )
        let enemy = context.roster.enemy.combatant
        _ = ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: enemy, in: context),
            keyword: .freeze, to: enemy, sourceActorID: "source",
            applyFightPacing: false, in: &context
        )
        try #expect((context.additionalControlSkipsByCombatantID[enemy.id] ?? 0) == 1)
    }

    @Test func chanceAboveOneGrantsFractionalSecondSkipDeterministically() throws {
        // 1.5 = guaranteed 1 + 50% for second; seed 0 hits second, seed 1 misses.
        var hitContext = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(stunExtendChancePercent: 1.5)
            )),
            seed: 0
        )
        let hitEnemy = hitContext.roster.enemy.combatant
        _ = ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: hitEnemy, in: hitContext),
            keyword: .stun, to: hitEnemy, sourceActorID: "source",
            applyFightPacing: false, in: &hitContext
        )
        try #expect((hitContext.additionalControlSkipsByCombatantID[hitEnemy.id] ?? 0) == 2)

        var missContext = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(stunExtendChancePercent: 1.5)
            )),
            seed: 1
        )
        let missEnemy = missContext.roster.enemy.combatant
        _ = ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: missEnemy, in: missContext),
            keyword: .stun, to: missEnemy, sourceActorID: "source",
            applyFightPacing: false, in: &missContext
        )
        try #expect((missContext.additionalControlSkipsByCombatantID[missEnemy.id] ?? 0) == 1)
    }
}
