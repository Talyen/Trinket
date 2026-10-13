import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ControlMeterEngineTests {
    @Test func `stun buildup displays the threshold used by seismic impact`() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 100,
            heroModifiers: CombatModifierProfile.withTriggers { $0.enemyStunThresholdReductionPercent = 0.25 },
        )
        let target = context.roster.enemy.combatant
        _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            10, keyword: .stun, to: target, sourceActorID: context.roster.hero.id,
            applyFightPacing: false, in: &context,
        ) }
        let meter = try #require(context.roster.activeEffects(for: target).first { $0.keyword == .stun })
        #expect(meter.effect.controlMeterValues?.threshold == 15)
        #expect(!context.roster.hasPendingActionSkip(for: target, keyword: .stun))
        _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            5, keyword: .stun, to: target, sourceActorID: context.roster.hero.id,
            applyFightPacing: false, in: &context,
        ) }
        #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
    }

    @Test func `reduced stun threshold triggers from another attackers buildup`() {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 100,
            heroModifiers: CombatModifierProfile.withTriggers { $0.enemyStunThresholdReductionPercent = 0.25 },
        )
        let target = context.roster.enemy.combatant
        _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            16, keyword: .stun, to: target, sourceActorID: context.roster.companion.id,
            applyFightPacing: false, in: &context,
        ) }
        #expect(!context.roster.hasControlStatus(for: target, keyword: .stun))

        let events = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            1, keyword: .stun, to: target, sourceActorID: context.roster.hero.id,
            applyFightPacing: false, in: &context,
        ) }

        #expect(events.contains { $0.effectKind == .controlTriggered })
        #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
    }

    @Test(arguments: [(Keyword.stun, 50, 15), (.freeze, 50, 15), (.stun, 100, 50)])
    func `control triggers at its threshold and consumes overflow`(keyword: Keyword, maximumHealth: Int, charge: Int) {
        var context = BattleTestFixtures.makePipelineContext(targetMaxHealth: maximumHealth)
        let target = context.roster.enemy.combatant
        let events = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            charge, keyword: keyword, to: target, sourceActorID: "source",
            applyFightPacing: charge == 50, in: &context,
        ) }
        #expect(events.contains { $0.effectKind == .controlTriggered && $0.keyword == keyword })
        if charge == 50 {
            #expect(!context.roster.activeEffects(for: target).contains {
                guard case let .controlMeter(_, amount, threshold) = $0.effect else { return false }
                return amount < threshold
            }, "Partial build-up should be consumed on trigger")
            #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
        }
    }

    @Test(arguments: [Keyword.stun, .freeze], [BattleParticipant.hero, .companion, .enemy])
    func `incoming control resists party charges and leaves enemy charges unchanged`(
        keyword: Keyword,
        recipient: BattleParticipant,
    ) throws {
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 50),
        )
        let target = context.roster[recipient].combatant
        _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            4, keyword: keyword, to: target, sourceActorID: recipient == .enemy ? context.hero.id : context.enemy.id,
            applyFightPacing: false, in: &context,
        ) }
        let meter = try #require(context.roster.activeEffects(for: target).first { $0.keyword == keyword })
        #expect(meter.effect.controlMeterValues?.amount == (recipient == .enemy ? 4 : 3))
    }

    @Test(arguments: [Keyword.stun, .freeze])
    func `stronger existing party resistance takes precedence`(keyword: Keyword) throws {
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 50),
            heroEffects: [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
            heroModifiers: CombatModifierProfile.withTriggers { $0.blockedControlBurnResistance = 0.5 },
        )
        _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            4, keyword: keyword, to: context.hero, sourceActorID: context.enemy.id,
            applyFightPacing: false, in: &context,
        ) }
        let meter = try #require(context.roster.activeEffects(for: context.hero).first { $0.keyword == keyword })
        #expect(meter.effect.controlMeterValues?.amount == 2)
    }

    @Test(arguments: [0, BattleTiming.controlStatusLingerTurns])
    func `control charge cannot retrigger a pending or lingering status`(remainingTurns: Int) {
        var context = BattleTestFixtures.makePipelineContext(
            targetEffects: [ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: remainingTurns)],
        )
        let target = context.roster.enemy.combatant
        #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun) == (remainingTurns == 0))
        #expect(context.roster.hasControlStatus(for: target, keyword: .stun))
        let events = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            15, keyword: .stun, to: target, sourceActorID: "source", in: &context,
        ) }
        #expect(events.isEmpty)
    }

    @Test func `apply buildup accumulates other keyword while skip pending`() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
            ],
        )
        let target = context.roster.enemy.combatant

        let events = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            3,
            keyword: .freeze,
            to: target,
            sourceActorID: "source",
            in: &context,
        ) }

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

    @Test func `reduced stun threshold still registers full meter and skip`() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 100,
            heroModifiers: CombatModifierProfile.withTriggers { $0.enemyStunThresholdReductionPercent = 0.25 },
        )
        let target = context.roster.enemy.combatant
        let baseThreshold = ControlMeterEngine.threshold(for: target, in: context)

        let events = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            baseThreshold,
            keyword: .stun,
            to: target,
            sourceActorID: "source",
            in: &context,
        ) }

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

    @Test(arguments: [
        (Keyword.stun, 0.0, UInt64(0), 1),
        (.stun, 1.0, 0, 2),
        (.freeze, 0.20, 0, 2),
        (.freeze, 0.20, 1, 1),
        (.stun, 1.5, 0, 3),
        (.stun, 1.5, 1, 2),
    ])
    func `control extension combines guaranteed skips and seeded fractional chances`(
        keyword: Keyword, chance: Double, seed: UInt64, expectedSkips: Int,
    ) {
        var triggers = CombatTraitTriggers()
        if keyword == .stun {
            triggers.stunExtendChancePercent = chance
        } else {
            triggers.freezeExtendChancePercent = chance
        }
        assertControlSkips(keyword: keyword, triggers: triggers, seed: seed, expected: expectedSkips)
    }

    @Test func `legacy freeze extra action skips maps to twenty percent`() {
        assertControlSkips(
            keyword: .freeze,
            triggers: CombatTraitTriggers.configured { $0.freezeExtraActionSkips = 1 },
            seed: 0, expected: 2,
        )
    }

    private func assertControlSkips(keyword: Keyword, triggers: CombatTraitTriggers, seed: UInt64, expected: Int) {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: triggers), seed: seed,
        )
        let enemy = context.roster.enemy.combatant
        _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: enemy, in: context),
            keyword: keyword, to: enemy, sourceActorID: "source",
            applyFightPacing: false, in: &context,
        ) }
        #expect(preventedActions(in: &context, for: enemy) == expected)
    }
}

private func preventedActions(in context: inout BattleState, for actor: Combatant) -> Int {
    var count = 0
    while context.roster.hasPendingActionSkip(for: actor), count < 5 {
        _ = CombatExecutor.run { await BattleTurnEngine.consumeActionSkip(for: actor, context: &context) }
        count += 1
    }
    return count
}

extension ControlMeterEngineTests {
    @Test func `large control extensions resolve promptly and saturate their skip allowance`() throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.freezeExtendChancePercent = Double(Int.max)
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile)
        _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            10, keyword: .freeze, to: battle.enemy, sourceActorID: battle.hero.id,
            applyFightPacing: false, in: &battle,
        ) }
        let status = try #require(battle.activeEffects(of: battle.enemy).first { $0.isAwaitingActionSkip })
        #expect(battle.additionalControlSkipsByEffectID[status.id] == Int.max)
    }

    @Test func `a fallen Stun source cannot earn Block from lingering control damage`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.onStunEnemyGainBlock = 6
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile)
        battle.roster.hero.currentHealth = 0
        let events = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            10, keyword: .stun, to: battle.enemy, sourceActorID: battle.hero.id,
            applyFightPacing: false, in: &battle,
        ) }
        #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .stun))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 0)
        #expect(!events.contains { $0.effectKind == .shieldApplied && $0.actorID == battle.hero.id })
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `glacial barrier rewards its wearer when either ally freezes the enemy`(source: BattleParticipant) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["wizard_freeze_t2_2"]),
        )
        battle.appliesFightPacing = false

        _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            10, keyword: .freeze, to: battle.enemy, sourceActorID: battle.roster[source].id,
            applyFightPacing: false, in: &battle,
        ) }

        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .freeze))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 3)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 0)
    }
}
