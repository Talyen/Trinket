import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct EffectHandlersTickTests {
    @Test func decayingDoTTicksUseSemanticDecayRules() throws {
        for (potency, expectedPotency, removes) in [(4, 2, false), (2, 1, false), (1, 0, true)] {
            var battle = EffectHandlersTestSupport.makeBattle()
            let burn = ActiveEffect(id: 1, effect: .burn(potency), remainingTicks: 0, sourceActorID: "hero")
            let outcome = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
            try #expect(outcome.events.count == (removes ? 0 : 1))
            try #expect(outcome.updatedStack?.effect.potency == expectedPotency)
            try #expect(outcome.removeAfter == removes)
        }

        var poisonBattle = EffectHandlersTestSupport.makeBattle()
        let poison = ActiveEffect(id: 1, effect: .poison(8), remainingTicks: 0, sourceActorID: "hero")
        let poisonOutcome = EffectHandlersTestSupport.dispatchTick(poison, target: poisonBattle.enemy, battle: &poisonBattle)
        try #expect(poisonOutcome.events.count == 1)
        try #expect(poisonOutcome.updatedStack?.effect.potency == 6)
        try #expect(!(poisonOutcome.removeAfter))

        for (remainingTicks, expectedTicks, removes) in [(3, 2, false), (1, 0, true)] {
            var battle = EffectHandlersTestSupport.makeBattle()
            let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: remainingTicks, sourceActorID: "hero")
            let outcome = EffectHandlersTestSupport.dispatchTick(bleed, target: battle.enemy, battle: &battle)
            try #expect(outcome.events.count == 1)
            try #expect(outcome.updatedStack?.remainingTicks == expectedTicks)
            try #expect(outcome.removeAfter == removes)
        }

        var expiredBattle = EffectHandlersTestSupport.makeBattle()
        let expired = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 0, sourceActorID: "hero")
        let expiredOutcome = EffectHandlersTestSupport.dispatchTick(expired, target: expiredBattle.enemy, battle: &expiredBattle)
        try #expect(expiredOutcome.events.isEmpty)
        try #expect(expiredOutcome.updatedStack == nil)
    }

    @Test(arguments: [
        Effect.shield(.block, 5),
        .mitigation(.armor, 2)
    ])
    func durationlessMitigationTicksLeaveStacksUntouched(effect: Effect) throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let stack = ActiveEffect(id: 1, effect: effect, remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(stack, target: battle.enemy, battle: &battle)
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
