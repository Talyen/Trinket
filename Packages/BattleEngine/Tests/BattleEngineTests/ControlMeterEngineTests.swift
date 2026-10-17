import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct ControlMeterEngineTests {
    @Test func `stun buildup displays the threshold used by seismic impact`() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 100,
            heroModifiers: CombatModifierProfile.withTriggers { $0.enemyStunThresholdReductionPercent = 0.25 },
        )
        let target = context.roster.enemy.combatant
        _ = context.chargeTestControl(10, keyword: .stun, to: target, sourceActorID: context.roster.hero.id, applyFightPacing: false)
        let meter = try #require(context.roster.activeEffects(for: target).first { $0.keyword == .stun })
        #expect(meter.effect.controlMeterValues?.threshold == 15)
        #expect(!context.roster.hasPendingActionSkip(for: target, keyword: .stun))
        _ = context.chargeTestControl(5, keyword: .stun, to: target, sourceActorID: context.roster.hero.id, applyFightPacing: false)
        #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
        let triggered = try #require(context.roster.activeEffects(for: target).first { $0.keyword == .stun }?.effect.controlMeterValues)
        let baseThreshold = ControlMeterEngine.threshold(for: target, in: context)
        #expect(triggered.amount == baseThreshold)
        #expect(triggered.threshold == baseThreshold)
    }

    @Test func `reduced stun threshold triggers from another attackers buildup`() {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 100,
            heroModifiers: CombatModifierProfile.withTriggers { $0.enemyStunThresholdReductionPercent = 0.25 },
        )
        let target = context.roster.enemy.combatant
        _ = context.chargeTestControl(16, keyword: .stun, to: target, sourceActorID: context.roster.companion.id, applyFightPacing: false)
        #expect(!context.roster.hasControlStatus(for: target, keyword: .stun))

        let events = context.chargeTestControl(
            1,
            keyword: .stun,
            to: target,
            sourceActorID: context.roster.hero.id,
            applyFightPacing: false,
        )

        #expect(events.contains { $0.effectKind == .controlTriggered })
        #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
    }

    @Test(arguments: [(Keyword.stun, 50, 15), (.freeze, 50, 15), (.stun, 100, 50)])
    func `control triggers at its threshold and consumes overflow`(keyword: Keyword, maximumHealth: Int, charge: Int) {
        var context = BattleTestFixtures.makePipelineContext(targetMaxHealth: maximumHealth)
        let target = context.roster.enemy.combatant
        let events = context.chargeTestControl(
            charge,
            keyword: keyword,
            to: target,
            sourceActorID: "source",
            applyFightPacing: charge == 50,
        )
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
        _ = context.chargeTestControl(
            4,
            keyword: keyword,
            to: target,
            sourceActorID: recipient == .enemy ? context.hero.id : context.enemy.id,
            applyFightPacing: false,
        )
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
        _ = context.chargeTestControl(4, keyword: keyword, to: context.hero, sourceActorID: context.enemy.id, applyFightPacing: false)
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
        let events = context.chargeTestControl(15, keyword: .stun, to: target, sourceActorID: "source")
        #expect(events.isEmpty)
    }

    @Test func `apply buildup accumulates other keyword while skip pending`() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
            ],
        )
        let target = context.roster.enemy.combatant

        let events = context.chargeTestControl(3, keyword: .freeze, to: target, sourceActorID: "source")

        try #expect(events.isEmpty)
        let freezeMeter = context.roster.activeEffects(for: target).first {
            guard case let .controlMeter(keyword, amount, _) = $0.effect else { return false }
            return keyword == .freeze && amount == 3
        }
        _ = try #require(freezeMeter)
        try #expect(context.roster.hasPendingActionSkip(for: target, keyword: .stun))
        try #expect(!(context.roster.hasPendingActionSkip(for: target, keyword: .freeze)))
    }

    @Test func `stun and freeze buildup advances independently on the same target`() {
        var context = BattleTestFixtures.makePipelineContext(appliesFightPacing: false)
        let target = context.enemy
        for (keyword, amount) in [(Keyword.stun, 4), (.freeze, 7), (.stun, 2)] {
            _ = context.chargeTestControl(amount, keyword: keyword, to: target, sourceActorID: context.hero.id, applyFightPacing: false)
        }
        let effects = context.activeEffects(of: target)
        #expect(effects.count { $0.effect.kind == .controlMeter } == 2)
        #expect(effects.first { $0.keyword == .stun }?.effect.controlMeterValues?.amount == 6)
        #expect(effects.first { $0.keyword == .freeze }?.effect.controlMeterValues?.amount == 7)
        #expect(!context.roster.hasPendingActionSkip(for: target))
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
        _ = context.chargeTestControl(
            ControlMeterEngine.threshold(for: enemy, in: context),
            keyword: keyword,
            to: enemy,
            sourceActorID: "source",
            applyFightPacing: false,
        )
        #expect(preventedActions(in: &context, for: enemy) == expected)
    }
}

private func preventedActions(in context: inout BattleState, for actor: Combatant) -> Int {
    var count = 0
    while context.roster.hasPendingActionSkip(for: actor), count < 5 {
        CombatExecutor.run { await BattleTurnEngine.consumeActionSkip(for: actor, context: &context) }
        count += 1
    }
    return count
}

extension ControlMeterEngineTests {
    @Test func `large control extensions resolve promptly and saturate their skip allowance`() throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.freezeExtendChancePercent = Double(Int.max)
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile)
        _ = battle.chargeTestControl(10, keyword: .freeze, to: battle.enemy, sourceActorID: battle.hero.id, applyFightPacing: false)
        let status = try #require(battle.activeEffects(of: battle.enemy).first { $0.isAwaitingActionSkip })
        #expect(battle.additionalControlSkipsByEffectID[status.id] == Int.max)
    }

    @Test func `a fallen Stun source cannot earn Block from lingering control damage`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.onStunEnemyGainBlock = 6
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile)
        battle.roster.hero.currentHealth = 0
        let events = battle.chargeTestControl(10, keyword: .stun, to: battle.enemy, sourceActorID: battle.hero.id, applyFightPacing: false)
        #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .stun))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 0)
        #expect(!events.contains { $0.effectKind == .shieldApplied && $0.actorID == battle.hero.id })
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `glacial barrier rewards its wearer when either ally freezes the enemy`(source: BattleParticipant) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["wizard_freeze_t2_2"]), appliesFightPacing: false,
        )

        _ = battle.chargeTestControl(
            10,
            keyword: .freeze,
            to: battle.enemy,
            sourceActorID: battle.roster[source].id,
            applyFightPacing: false,
        )

        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .freeze))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 3)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 0)
    }
}
