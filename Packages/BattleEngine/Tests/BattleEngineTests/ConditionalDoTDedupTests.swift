import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct ConditionalDoTDedupTests {
    @Test func shouldSkipImmediateDoTWhenKeywordMatchesRegardlessOfPotency() throws {
        let action = ActionApplyContext(pairedDirectDamage: [(.burn, 9)])
        try #expect(action.shouldSkipImmediateDoT(keyword: .burn))
    }

    @Test func burnHandlerSkipsImmediateDamageWhenBoostedPairedBurnExists() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        let hero = battle.hero
        let action = ActionApplyContext(pairedDirectDamage: [(.burn, 9)])
        let outcome: EffectApplyOutcome = try battle.withEngineContext { context in
            try #require(EffectHandlers.all[.burn]?.apply(
                .burn(6),
                ability: Ability.combustion,
                source: hero,
                target: enemy,
                action: action,
                in: &context
            ))
        }
        try #expect(outcome.didApply)
        try #expect(!(outcome.events.contains { $0.kind == .status && $0.keyword == .burn }))
    }

    @Test func poisonHandlerSkipsImmediateDamageWhenBoostedPairedPoisonExists() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        let hero = battle.hero
        let action = ActionApplyContext(pairedDirectDamage: [(.poison, 4)])
        let outcome: EffectApplyOutcome = try battle.withEngineContext { context in
            try #require(EffectHandlers.all[.poison]?.apply(
                .poison(3),
                ability: Ability.venomArrow,
                source: hero,
                target: enemy,
                action: action,
                in: &context
            ))
        }
        try #expect(outcome.didApply)
        try #expect(!(outcome.events.contains { $0.kind == .status && $0.keyword == .poison }))
    }
}
