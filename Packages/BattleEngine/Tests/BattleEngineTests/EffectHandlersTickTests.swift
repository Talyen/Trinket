import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct EffectHandlersTickTests {
    @Test func bleedTickDealsDamageAndDecrementsRemainingTicks() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 3, sourceActorID: "hero")
        var outcome = EffectHandlersTestSupport.dispatchTick(bleed, target: battle.enemy, battle: &battle)
        try #expect(outcome.events.count == 1)
        try #expect(outcome.updatedStack?.remainingTicks == 2)
        try #expect(!(outcome.removeAfter))
    }

    @Test func bleedTickWithZeroRemainingTicksIsNoOp() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(bleed, target: battle.enemy, battle: &battle)
        try #expect(outcome.events.isEmpty)
        try #expect(outcome.updatedStack == nil)
    }

    @Test func bleedTickAtOneRemainingTickMarksForRemoval() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 1, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(bleed, target: battle.enemy, battle: &battle)
        try #expect(outcome.events.count == 1)
        try #expect(outcome.updatedStack?.remainingTicks == 0)
        try #expect(outcome.removeAfter)
    }

    @Test func burnTickHalvesPotency() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
        try #expect(outcome.events.count == 1)
        try #expect(outcome.updatedStack?.effect.potency == 2)
        try #expect(!(outcome.removeAfter))
    }

    @Test func burnTickAtPotencyTwoGoesToOne() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
        try #expect(outcome.events.count == 1)
        try #expect(outcome.updatedStack?.effect.potency == 1)
        try #expect(!(outcome.removeAfter))
    }

    @Test func burnTickAtPotencyOneIsMarkedForRemoval() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(1), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
        try #expect(outcome.events.count == 0)
        try #expect(outcome.updatedStack?.effect.potency == 0)
        try #expect(outcome.removeAfter)
    }

    @Test func poisonTickDecaysPotency() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let poison = ActiveEffect(id: 1, effect: .poison(8), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(poison, target: battle.enemy, battle: &battle)
        try #expect(outcome.events.count == 1)
        // 8 - max(1, 8 * 25 / 100) = 8 - 2 = 6
        try #expect(outcome.updatedStack?.effect.potency == 6)
        try #expect(!(outcome.removeAfter))
    }

    @Test func poisonTickAtPotencyTwoIsMarkedForRemoval() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let poison = ActiveEffect(id: 1, effect: .poison(2), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(poison, target: battle.enemy, battle: &battle)
        // 2 - max(1, 0) = 1
        try #expect(outcome.events.count == 1)
        try #expect(outcome.updatedStack?.effect.potency == 1)
        try #expect(!(outcome.removeAfter))
    }

    @Test func defaultTickLeavesDurationlessBlockUntouched() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(shield, target: battle.enemy, battle: &battle)
        try #expect(outcome.events.isEmpty)
        try #expect(outcome.updatedStack == nil)
        try #expect(!(outcome.removeAfter))
    }

    @Test func mitigationTickLeavesDurationlessArmorUntouched() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let mitigation = ActiveEffect(
            id: 1,
            effect: .mitigation(.armor, 2),
            remainingTicks: 0,
            sourceActorID: "hero"
        )
        let outcome = EffectHandlersTestSupport.dispatchTick(mitigation, target: battle.enemy, battle: &battle)
        try #expect(outcome.events.isEmpty)
        try #expect(outcome.updatedStack == nil)
        try #expect(!(outcome.removeAfter))
    }

    @Test func leechTickDecrementsRemainingDuration() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let leech = ActiveEffect(
            id: 1,
            effect: .standardLeechBuff,
            remainingTicks: 2,
            sourceActorID: "hero"
        )
        let outcome = EffectHandlersTestSupport.dispatchTick(leech, target: battle.hero, battle: &battle)
        try #expect(outcome.events.isEmpty)
        try #expect(outcome.updatedStack?.remainingTicks == 1)
        try #expect(!(outcome.removeAfter))
    }
}
