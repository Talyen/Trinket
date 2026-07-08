import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct EffectHandlersTickTests {
    @Test func bleedTickDealsDamageAndDecrementsRemainingTicks() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 3, sourceActorID: "hero")
        var outcome = EffectHandlersTestSupport.dispatchTick(bleed, target: battle.enemy, battle: &battle)
        #expect(outcome.events.count == 1)
        #expect(outcome.updatedStack?.remainingTicks == 2)
        #expect(!(outcome.removeAfter))
    }

    @Test func bleedTickWithZeroRemainingTicksIsNoOp() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(bleed, target: battle.enemy, battle: &battle)
        #expect(outcome.events.isEmpty)
        #expect(outcome.updatedStack == nil)
    }

    @Test func bleedTickAtOneRemainingTickMarksForRemoval() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 1, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(bleed, target: battle.enemy, battle: &battle)
        #expect(outcome.events.count == 1)
        #expect(outcome.updatedStack?.remainingTicks == 0)
        #expect(outcome.removeAfter)
    }

    @Test func burnTickHalvesPotency() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
        #expect(outcome.events.count == 1)
        #expect(outcome.updatedStack?.effect.potency == 2)
        #expect(!(outcome.removeAfter))
    }

    @Test func burnTickAtPotencyTwoGoesToOne() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
        #expect(outcome.events.count == 1)
        #expect(outcome.updatedStack?.effect.potency == 1)
        #expect(!(outcome.removeAfter))
    }

    @Test func burnTickAtPotencyOneIsMarkedForRemoval() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(1), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
        #expect(outcome.events.count == 0)
        #expect(outcome.updatedStack?.effect.potency == 0)
        #expect(outcome.removeAfter)
    }

    @Test func poisonTickDecaysPotency() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let poison = ActiveEffect(id: 1, effect: .poison(8), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(poison, target: battle.enemy, battle: &battle)
        #expect(outcome.events.count == 1)
        // 8 - max(1, 8 * 25 / 100) = 8 - 2 = 6
        #expect(outcome.updatedStack?.effect.potency == 6)
        #expect(!(outcome.removeAfter))
    }

    @Test func poisonTickAtPotencyTwoIsMarkedForRemoval() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let poison = ActiveEffect(id: 1, effect: .poison(2), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(poison, target: battle.enemy, battle: &battle)
        // 2 - max(1, 0) = 1
        #expect(outcome.events.count == 1)
        #expect(outcome.updatedStack?.effect.potency == 1)
        #expect(!(outcome.removeAfter))
    }

    @Test func defaultTickDecrementsDurationForTickableBuffs() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 5, 6), remainingTicks: 6, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(shield, target: battle.enemy, battle: &battle)
        #expect(outcome.events.isEmpty)
        #expect(outcome.updatedStack?.remainingTicks == 5)
        #expect(!(outcome.removeAfter))
    }

    @Test func mitigationTickExpiresAtZeroRemainingTicks() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let mitigation = ActiveEffect(
            id: 1,
            effect: .mitigation(.armor, 0.25, 3),
            remainingTicks: 1,
            sourceActorID: "hero"
        )
        let outcome = EffectHandlersTestSupport.dispatchTick(mitigation, target: battle.enemy, battle: &battle)
        #expect(outcome.events.isEmpty)
        #expect(outcome.updatedStack?.remainingTicks == 0)
        #expect(outcome.removeAfter)
    }

    @Test func leechTickDecrementsRemainingDuration() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let leech = ActiveEffect(
            id: 1,
            effect: .standardLeechBuff,
            remainingTicks: 2,
            sourceActorID: "hero"
        )
        let outcome = EffectHandlersTestSupport.dispatchTick(leech, target: battle.hero, battle: &battle)
        #expect(outcome.events.isEmpty)
        #expect(outcome.updatedStack?.remainingTicks == 1)
        #expect(!(outcome.removeAfter))
    }
}
