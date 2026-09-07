import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct ControlMeterEngineTests {
    @Test func `reduced stun threshold triggers from another attackers buildup`() {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 100,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                control: ControlTriggers(enemyStunThresholdReductionPercent: 0.25),
            )),
        )
        let target = context.roster.enemy.combatant
        _ = ControlMeterEngine.applyMeterCharge(
            16, keyword: .stun, to: target, sourceActorID: context.roster.companion.id,
            applyFightPacing: false, in: &context,
        )
        #expect(!context.roster.hasControlStatus(for: target, keyword: .stun))

        let events = ControlMeterEngine.applyMeterCharge(
            1, keyword: .stun, to: target, sourceActorID: context.roster.hero.id,
            applyFightPacing: false, in: &context,
        )

        #expect(events.contains { $0.effectKind == .controlTriggered })
        #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
    }

    @Test(arguments: [Keyword.stun, Keyword.freeze])
    func `apply buildup triggers control at threshold`(keyword: Keyword) throws {
        var context = BattleTestFixtures.makePipelineContext()
        let target = context.roster.enemy.combatant
        let events = ControlMeterEngine.applyMeterCharge(
            15,
            keyword: keyword,
            to: target,
            sourceActorID: "source",
            applyFightPacing: false,
            in: &context,
        )
        try #expect(events.contains { $0.effectKind == .controlTriggered && $0.keyword == keyword })
    }

    @Test(arguments: [Keyword.stun, Keyword.freeze])
    func `party members resist incoming control`(keyword: Keyword) throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 50)
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
        )

        for target in [hero, companion] {
            _ = ControlMeterEngine.applyMeterCharge(
                4,
                keyword: keyword,
                to: target,
                sourceActorID: enemy.id,
                applyFightPacing: false,
                in: &context,
            )

            let meter = try #require(
                context.roster.activeEffects(for: target).first { $0.keyword == keyword },
            )
            let values = try #require(meter.effect.controlMeterValues)
            try #expect(values.amount == 3)
        }
    }

    @Test(arguments: [Keyword.stun, Keyword.freeze])
    func `enemy receives unmodified incoming control`(keyword: Keyword) throws {
        var context = BattleTestFixtures.makePipelineContext()
        let target = context.roster.enemy.combatant

        _ = ControlMeterEngine.applyMeterCharge(
            4,
            keyword: keyword,
            to: target,
            sourceActorID: "source",
            applyFightPacing: false,
            in: &context,
        )

        let meter = try #require(
            context.roster.activeEffects(for: target).first { $0.keyword == keyword },
        )
        let values = try #require(meter.effect.controlMeterValues)
        try #expect(values.amount == 4)
    }

    @Test(arguments: [Keyword.stun, Keyword.freeze])
    func `stronger existing party resistance takes precedence`(keyword: Keyword) throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 50)
        let block = ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroEffects: [block],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(blockedControlBurnResistance: 0.5),
            )),
        )

        _ = ControlMeterEngine.applyMeterCharge(
            4,
            keyword: keyword,
            to: hero,
            sourceActorID: enemy.id,
            applyFightPacing: false,
            in: &context,
        )

        let meter = try #require(
            context.roster.activeEffects(for: hero).first { $0.keyword == keyword },
        )
        let values = try #require(meter.effect.controlMeterValues)
        try #expect(values.amount == 2)
    }

    @Test func `apply buildup no duplicate when same keyword skip pending`() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
            ],
        )
        let events = ControlMeterEngine.applyMeterCharge(
            15,
            keyword: .stun,
            to: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context,
        )
        try #expect(events.isEmpty)
    }

    @Test func `apply buildup no duplicate during control status linger`() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetEffects: [
                ActiveEffect(
                    id: 1,
                    effect: .controlMeter(.stun, 10, 10),
                    remainingTurns: BattleTiming.controlStatusLingerTurns,
                ),
            ],
        )
        let target = context.roster.enemy.combatant
        try #expect(!(context.roster.hasPendingActionSkip(for: target, keyword: .stun)))
        try #expect(context.roster.hasControlStatus(for: target, keyword: .stun))

        let events = ControlMeterEngine.applyMeterCharge(
            15,
            keyword: .stun,
            to: target,
            sourceActorID: "source",
            in: &context,
        )
        try #expect(events.isEmpty)
    }

    @Test func `apply buildup accumulates other keyword while skip pending`() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
            ],
        )
        let target = context.roster.enemy.combatant

        let events = ControlMeterEngine.applyMeterCharge(
            3,
            keyword: .freeze,
            to: target,
            sourceActorID: "source",
            in: &context,
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

    @Test func `stun and freeze meters coexist on same target`() throws {
        let context = BattleTestFixtures.makePipelineContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 4, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .controlMeter(.freeze, 7, 10), remainingTurns: 0),
            ],
        )
        let target = context.roster.enemy.combatant
        let meters = context.roster.activeEffects(for: target).compactMap(\.effect.controlMeterValues)
        try #expect(meters.count == 2)
    }

    @Test func `overflow charge is consumed on trigger`() throws {
        var context = BattleTestFixtures.makePipelineContext(targetMaxHealth: 100)
        let target = context.roster.enemy.combatant

        let events = ControlMeterEngine.applyMeterCharge(
            50,
            keyword: .stun,
            to: target,
            sourceActorID: "source",
            in: &context,
        )

        try #expect(events.contains { $0.effectKind == .controlTriggered })
        try #expect(
            !context.roster.activeEffects(for: target).contains {
                guard case let .controlMeter(_, amount, threshold) = $0.effect else { return false }
                return amount < threshold
            },
            "Partial build-up should be consumed on trigger",
        )
        try #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
    }

    @Test func `reduced stun threshold still registers full meter and skip`() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 100,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                control: ControlTriggers(enemyStunThresholdReductionPercent: 0.25),
            )),
        )
        let target = context.roster.enemy.combatant
        let baseThreshold = ControlMeterEngine.threshold(for: target, in: context)

        let events = ControlMeterEngine.applyMeterCharge(
            baseThreshold,
            keyword: .stun,
            to: target,
            sourceActorID: "source",
            in: &context,
        )

        try #expect(events.contains { $0.effectKind == .controlTriggered })
        try #expect(context.roster.hasControlStatus(for: target, keyword: .stun))
        try #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
        let meter = try #require(
            context.roster.activeEffects(for: target)
                .first { $0.keyword == .stun }?
                .effect.controlMeterValues,
        )
        try #expect(meter.threshold == baseThreshold, "stored basis stays canonical (base)")
        try #expect(meter.amount == baseThreshold, "a full meter reads as full against its stored basis")
    }

    @Test func `stun extend chance zero grants no extra skip`() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(stunExtendChancePercent: 0),
            )),
            seed: 0,
        )
        let enemy = context.roster.enemy.combatant
        let threshold = ControlMeterEngine.threshold(for: enemy, in: context)
        _ = ControlMeterEngine.applyMeterCharge(
            threshold, keyword: .stun, to: enemy, sourceActorID: "source",
            applyFightPacing: false, in: &context,
        )
        try #expect((context.additionalControlSkipsByCombatantID[enemy.id] ?? 0) == 0)
    }

    @Test func `stun extend chance one guarantees extra skip`() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(stunExtendChancePercent: 1.0),
            )),
            seed: 0,
        )
        let enemy = context.roster.enemy.combatant
        let threshold = ControlMeterEngine.threshold(for: enemy, in: context)
        _ = ControlMeterEngine.applyMeterCharge(
            threshold, keyword: .stun, to: enemy, sourceActorID: "source",
            applyFightPacing: false, in: &context,
        )
        try #expect((context.additionalControlSkipsByCombatantID[enemy.id] ?? 0) == 1)
    }

    @Test func `freeze extend chance respects seed`() throws {
        var hitContext = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(freezeExtendChancePercent: 0.20),
            )),
            seed: 0,
        )
        let hitEnemy = hitContext.roster.enemy.combatant
        _ = ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: hitEnemy, in: hitContext),
            keyword: .freeze, to: hitEnemy, sourceActorID: "source",
            applyFightPacing: false, in: &hitContext,
        )
        try #expect((hitContext.additionalControlSkipsByCombatantID[hitEnemy.id] ?? 0) == 1)

        var missContext = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(freezeExtendChancePercent: 0.20),
            )),
            seed: 1,
        )
        let missEnemy = missContext.roster.enemy.combatant
        _ = ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: missEnemy, in: missContext),
            keyword: .freeze, to: missEnemy, sourceActorID: "source",
            applyFightPacing: false, in: &missContext,
        )
        try #expect((missContext.additionalControlSkipsByCombatantID[missEnemy.id] ?? 0) == 0)
    }

    @Test func `legacy freeze extra action skips maps to twenty percent`() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(freezeExtraActionSkips: 1),
            )),
            seed: 0,
        )
        let enemy = context.roster.enemy.combatant
        _ = ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: enemy, in: context),
            keyword: .freeze, to: enemy, sourceActorID: "source",
            applyFightPacing: false, in: &context,
        )
        try #expect((context.additionalControlSkipsByCombatantID[enemy.id] ?? 0) == 1)
    }

    @Test func `chance above one grants fractional second skip deterministically`() throws {
        var hitContext = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(stunExtendChancePercent: 1.5),
            )),
            seed: 0,
        )
        let hitEnemy = hitContext.roster.enemy.combatant
        _ = ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: hitEnemy, in: hitContext),
            keyword: .stun, to: hitEnemy, sourceActorID: "source",
            applyFightPacing: false, in: &hitContext,
        )
        try #expect((hitContext.additionalControlSkipsByCombatantID[hitEnemy.id] ?? 0) == 2)

        var missContext = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(stunExtendChancePercent: 1.5),
            )),
            seed: 1,
        )
        let missEnemy = missContext.roster.enemy.combatant
        _ = ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: missEnemy, in: missContext),
            keyword: .stun, to: missEnemy, sourceActorID: "source",
            applyFightPacing: false, in: &missContext,
        )
        try #expect((missContext.additionalControlSkipsByCombatantID[missEnemy.id] ?? 0) == 1)
    }
}
