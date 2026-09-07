import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct EffectHandlersTurnTests {
    @Test(arguments: [false, true])
    func `enemy avatar targets surviving companion`(onTurn: Bool) {
        var battle = BattleStateTestFactory.makeBattle()
        battle.withEngineContext { context in
            context.appliesFightPacing = false
            context.roster.mutateRuntime(for: context.hero) { $0.currentHealth = 0 }
        }
        let before = battle.health(of: battle.companion)
        let effect = Effect.avatar(holyDamage: 2, blockPerTurn: 2, turns: 2)
        if onTurn {
            _ = EffectHandlersTestSupport.dispatchTick(
                ActiveEffect(id: 1, effect: effect, remainingTurns: 2, sourceActorID: battle.enemy.id),
                target: battle.enemy, battle: &battle,
            )
        } else {
            _ = EffectHandlersTestSupport.dispatch(
                effect, source: battle.enemy, target: battle.enemy, battle: &battle,
            )
        }
        #expect(battle.health(of: battle.companion) == before - 2)
        #expect(battle.health(of: battle.hero) == 0)
    }

    @Test(arguments: [false, true])
    func `recurring block uses bonuses and gain triggers`(fromTalent: Bool) {
        var triggers = CombatTraitTriggers()
        triggers.blockGainThornsPercent = 1
        triggers.blockPerTurn = 2
        var battle = BattleStateTestFactory.makeBattle(
            heroModifiers: CombatModifierProfile(blockGainedBonus: 3, triggers: triggers),
        )
        battle.withEngineContext { $0.appliesFightPacing = false }
        let effect = Effect.avatar(holyDamage: 1, blockPerTurn: 2, turns: 2)
        if fromTalent {
            battle.withEngineContext { context in
                _ = CombatTriggerEngine.turnBlock(for: context.hero, in: &context)
                _ = CombatTriggerEngine.turnBlock(for: context.hero, in: &context)
            }
        } else {
            _ = EffectHandlersTestSupport.dispatch(
                effect, source: battle.hero, target: battle.hero, battle: &battle,
            )
            _ = EffectHandlersTestSupport.dispatchTick(
                ActiveEffect(id: 1, effect: effect, remainingTurns: 2, sourceActorID: battle.hero.id),
                target: battle.hero, battle: &battle,
            )
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 10)
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == .thorns(10) })
    }

    @Test func `frozen enemy avatar cannot gain block`() {
        var triggers = CombatTraitTriggers()
        triggers.frozenEnemyCannotBlockOrHeal = true
        var battle = BattleStateTestFactory.makeBattle(
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0),
            ],
            heroModifiers: CombatModifierProfile(triggers: triggers),
        )
        _ = EffectHandlersTestSupport.dispatchTick(
            ActiveEffect(
                id: 2, effect: .avatar(holyDamage: 1, blockPerTurn: 2, turns: 2),
                remainingTurns: 2, sourceActorID: battle.enemy.id,
            ),
            target: battle.enemy, battle: &battle,
        )
        #expect(BattleTestFixtures.shieldPoints(for: battle.enemy, in: battle) == 0)
    }

    @Test func `decaying do T ticks use semantic decay rules`() throws {
        for (potency, expectedPotency, removes) in [(4, 2, false), (2, 1, false), (1, 0, true)] {
            var battle = BattleStateTestFactory.makeBattle()
            let burn = ActiveEffect(id: 1, effect: .burn(potency), remainingTurns: 0, sourceActorID: "hero")
            let outcome = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
            try #expect(outcome.events.count == (removes ? 0 : 1))
            try #expect(outcome.updatedStack?.effect.potency == expectedPotency)
            try #expect(outcome.removeAfter == removes)
        }

        var poisonBattle = BattleStateTestFactory.makeBattle()
        let poison = ActiveEffect(id: 1, effect: .poison(8), remainingTurns: 0, sourceActorID: "hero")
        let poisonOutcome = EffectHandlersTestSupport.dispatchTick(poison, target: poisonBattle.enemy, battle: &poisonBattle)
        try #expect(poisonOutcome.events.count == 1)
        try #expect(poisonOutcome.updatedStack?.effect.potency == 6)
        try #expect(!(poisonOutcome.removeAfter))

        for (remainingTurns, expectedTicks, removes) in [(3, 2, false), (1, 0, true)] {
            var battle = BattleStateTestFactory.makeBattle()
            let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTurns: remainingTurns, sourceActorID: "hero")
            let outcome = EffectHandlersTestSupport.dispatchTick(bleed, target: battle.enemy, battle: &battle)
            try #expect(outcome.events.count == 1)
            try #expect(outcome.updatedStack?.remainingTurns == expectedTicks)
            try #expect(outcome.removeAfter == removes)
        }

        var expiredBattle = BattleStateTestFactory.makeBattle()
        let expired = ActiveEffect(id: 1, effect: .bleed(3), remainingTurns: 0, sourceActorID: "hero")
        let expiredOutcome = EffectHandlersTestSupport.dispatchTick(expired, target: expiredBattle.enemy, battle: &expiredBattle)
        try #expect(expiredOutcome.events.isEmpty)
        try #expect(expiredOutcome.updatedStack == nil)
    }

    @Test func `burn decay slow talent slows burn applied by its owner`() throws {
        var battle = BattleStateTestFactory.makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(10), remainingTurns: 2, sourceActorID: "hero")
        let baseline = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
        try #expect(baseline.updatedStack?.effect.potency == 5)

        var slowedBattle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    dot: DotTriggers(burnDecaySlowPercent: 0.4),
                ),
            ),
        )
        let slowedBurn = ActiveEffect(id: 1, effect: .burn(10), remainingTurns: 2, sourceActorID: "source")
        let slowed = EffectHandlersTestSupport.dispatchTick(
            slowedBurn,
            target: slowedBattle.roster.enemy.combatant,
            battle: &slowedBattle,
        )
        try #expect(slowed.updatedStack?.effect.potency == 7)
    }

    @Test(arguments: [
        Effect.shield(.block, 5),
    ])
    func `durationless mitigation ticks leave stacks untouched`(effect: Effect) throws {
        var battle = BattleStateTestFactory.makeBattle()
        let stack = ActiveEffect(id: 1, effect: effect, remainingTurns: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(stack, target: battle.enemy, battle: &battle)
        try #expect(outcome.events.isEmpty)
        try #expect(outcome.updatedStack == nil)
        try #expect(!(outcome.removeAfter))
    }
}
