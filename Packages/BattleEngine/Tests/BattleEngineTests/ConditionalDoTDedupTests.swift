import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct ConditionalDoTDedupTests {
    @Test func shouldSkipImmediateDoTWhenKeywordMatchesRegardlessOfPotency() throws {
        let action = ActionApplyContext(pairedDirectDamage: [PairedDamage(keyword: .burn, amount: 9)])
        try #expect(action.shouldSkipImmediateDoT(keyword: .burn))
    }

    private struct DoTCase: Sendable {
        let keyword: Keyword
        let handlerKey: EffectKind
        let pairedAmount: Int
        let appliedPotency: Int
        let ability: Ability

        static let burn = Self(keyword: .burn, handlerKey: .burn, pairedAmount: 9, appliedPotency: 6, ability: .combustion)
        static let poison = Self(keyword: .poison, handlerKey: .poison, pairedAmount: 4, appliedPotency: 3, ability: .venomArrow)
    }

    @Test(arguments: [Self.DoTCase.burn, .poison])
    private func handlerSkipsImmediateDamageWhenBoostedPairedDoTExists(_ testCase: DoTCase) throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        let hero = battle.hero
        let action = ActionApplyContext(pairedDirectDamage: [PairedDamage(keyword: testCase.keyword, amount: testCase.pairedAmount)])
        let effect: Effect = testCase.keyword == .burn ? .burn(testCase.appliedPotency) : .poison(testCase.appliedPotency)
        let outcome: EffectApplyOutcome = try battle.withEngineContext { context in
            try #require(EffectHandlers.all[testCase.handlerKey]?.apply(
                effect,
                ability: testCase.ability,
                source: hero,
                target: enemy,
                action: action,
                in: &context
            ))
        }
        try #expect(outcome.didApply)
        try #expect(!(outcome.events.contains { $0.kind == .status && $0.keyword == testCase.keyword }))
    }
}
