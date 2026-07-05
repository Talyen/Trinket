import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class ConditionalDoTDedupTests: XCTestCase {
    func testShouldSkipImmediateDoTWhenKeywordMatchesRegardlessOfPotency() {
        let action = ActionApplyContext(pairedDirectDamage: [(.burn, 9)])
        XCTAssertTrue(action.shouldSkipImmediateDoT(keyword: .burn))
    }

    func testBurnHandlerSkipsImmediateDamageWhenBoostedPairedBurnExists() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        let hero = battle.hero
        let action = ActionApplyContext(pairedDirectDamage: [(.burn, 9)])
        let outcome: EffectApplyOutcome = try battle.withEngineContext { context in
            try XCTUnwrap(EffectHandlers.all[.burn]?.apply(
                .burn(6),
                ability: Ability.combustion,
                source: hero,
                target: enemy,
                action: action,
                in: &context
            ))
        }
        XCTAssertTrue(outcome.didApply)
        XCTAssertFalse(outcome.events.contains { $0.kind == .status && $0.keyword == .burn })
    }

    func testPoisonHandlerSkipsImmediateDamageWhenBoostedPairedPoisonExists() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        let hero = battle.hero
        let action = ActionApplyContext(pairedDirectDamage: [(.poison, 4)])
        let outcome: EffectApplyOutcome = try battle.withEngineContext { context in
            try XCTUnwrap(EffectHandlers.all[.poison]?.apply(
                .poison(3),
                ability: Ability.venomArrow,
                source: hero,
                target: enemy,
                action: action,
                in: &context
            ))
        }
        XCTAssertTrue(outcome.didApply)
        XCTAssertFalse(outcome.events.contains { $0.kind == .status && $0.keyword == .poison })
    }
}
