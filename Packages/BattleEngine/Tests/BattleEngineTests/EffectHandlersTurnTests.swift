import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct EffectHandlersTurnTests {
    @Test(arguments: [false, true])
    func `enemy avatar targets surviving companion`(onTurn: Bool) {
        var battle = BattleStateTestFactory.makeBattle(appliesFightPacing: false)
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 0 }
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
            dealOpeningHand: false, appliesFightPacing: false,
        )
        let effect = Effect.avatar(holyDamage: 1, blockPerTurn: 2, turns: 2)
        if fromTalent {
            CombatTriggerEngine.turnBlock(for: battle.hero, in: &battle)
            CombatTriggerEngine.turnBlock(for: battle.hero, in: &battle)
        } else {
            _ = EffectHandlersTestSupport.dispatch(
                effect, battle: &battle,
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
        var battle = BattleStateTestFactory.makeBattle(
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0),
            ],
            heroModifiers: CombatModifierProfile.withTriggers { $0.frozenEnemyCannotBlockOrHeal = true },
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

    @Test(arguments: [Keyword.freeze, .stun])
    func `recurring control damage builds control on application and subsequent turns`(keyword: Keyword) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 200, dealOpeningHand: false, appliesFightPacing: false)
        let effect = Effect.recurringDamage(keyword, 2, 2)
        _ = EffectHandlersTestSupport.dispatch(
            effect, target: battle.enemy, battle: &battle,
        )
        for expectedAmount in [2, 4] {
            #expect(battle.health(of: battle.enemy) == 200 - expectedAmount)
            #expect(battle.activeEffects(of: battle.enemy).contains {
                if case let .controlMeter(appliedKeyword, amount, _) = $0.effect {
                    return appliedKeyword == keyword && amount == expectedAmount
                }
                return false
            })
            if expectedAmount == 2 {
                _ = EffectHandlersTestSupport.dispatchTick(
                    ActiveEffect(id: 10, effect: effect, remainingTurns: 2, sourceActorID: battle.hero.id),
                    target: battle.enemy, battle: &battle,
                )
            }
        }
    }

    @Test(arguments: [
        (Effect.burn(4), 0, Effect?.some(.burn(2)), 0, 1),
        (.burn(2), 0, .burn(1), 0, 1),
        (.burn(1), 0, nil, 0, 0),
        (.poison(8), 0, .poison(6), 0, 1),
        (.bleed(3), 3, .bleed(3), 2, 1),
        (.bleed(3), 1, nil, 0, 1),
        (.bleed(3), 0, .bleed(3), 0, 0),
    ])
    func `damage over time advances potency duration and expiry`(
        effect: Effect, turns: Int, expected: Effect?, remainingTurns: Int, eventCount: Int,
    ) {
        var battle = BattleStateTestFactory.makeBattle()
        let active = ActiveEffect(id: 1, effect: effect, remainingTurns: turns, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(active, target: battle.enemy, battle: &battle)
        #expect(outcome.events.count == eventCount)
        var replacement = active
        replacement.effect = expected ?? effect
        replacement.remainingTurns = remainingTurns
        #expect(outcome.currentEffect == (expected == nil ? nil : replacement))
    }

    @Test func `burn decay slow talent slows burn applied by its owner`() throws {
        var battle = BattleStateTestFactory.makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(10), remainingTurns: 2, sourceActorID: "hero")
        let baseline = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
        try #expect(baseline.currentEffect?.effect.potency == 5)

        var slowedBattle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile.withTriggers { $0.burnDecaySlowPercent = 0.4 },
        )
        let slowedBurn = ActiveEffect(id: 1, effect: .burn(10), remainingTurns: 2, sourceActorID: "source")
        let slowed = EffectHandlersTestSupport.dispatchTick(
            slowedBurn,
            target: slowedBattle.roster.enemy.combatant,
            battle: &slowedBattle,
        )
        try #expect(slowed.currentEffect?.effect.potency == 7)
    }

    @Test(arguments: [
        Effect.shield(.block, 5),
    ])
    func `durationless mitigation ticks leave stacks untouched`(effect: Effect) throws {
        var battle = BattleStateTestFactory.makeBattle()
        let stack = ActiveEffect(id: 1, effect: effect, remainingTurns: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(stack, target: battle.enemy, battle: &battle)
        try #expect(outcome.events.isEmpty)
        try #expect(outcome.currentEffect == stack)
    }
}
