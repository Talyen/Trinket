import XCTest
@testable import Trinket

final class EffectHandlersTickTests: XCTestCase {
    func testBleedTickDealsDamageAndDecrementsRemainingTicks() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 3, sourceActorID: "hero")
        var outcome = EffectHandlersTestSupport.dispatchTick(bleed, target: battle.enemy, battle: &battle)
        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.updatedStack?.remainingTicks, 2)
        XCTAssertFalse(outcome.removeAfter)
    }

    func testBleedTickWithZeroRemainingTicksIsNoOp() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(bleed, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.events.isEmpty)
        XCTAssertNil(outcome.updatedStack)
    }

    func testBleedTickAtOneRemainingTickMarksForRemoval() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 1, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(bleed, target: battle.enemy, battle: &battle)
        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.updatedStack?.remainingTicks, 0)
        XCTAssertTrue(outcome.removeAfter)
    }

    func testBurnTickHalvesPotency() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.updatedStack?.effect.potency, 2)
        XCTAssertFalse(outcome.removeAfter)
    }

    func testBurnTickAtPotencyTwoGoesToOne() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.updatedStack?.effect.potency, 1)
        XCTAssertFalse(outcome.removeAfter)
    }

    func testBurnTickAtPotencyOneIsMarkedForRemoval() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(1), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(burn, target: battle.enemy, battle: &battle)
        XCTAssertEqual(outcome.events.count, 0)
        XCTAssertEqual(outcome.updatedStack?.effect.potency, 0)
        XCTAssertTrue(outcome.removeAfter)
    }

    func testPoisonTickDecaysPotency() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let poison = ActiveEffect(id: 1, effect: .poison(8), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(poison, target: battle.enemy, battle: &battle)
        XCTAssertEqual(outcome.events.count, 1)
        // 8 - max(1, 8 * 25 / 100) = 8 - 2 = 6
        XCTAssertEqual(outcome.updatedStack?.effect.potency, 6)
        XCTAssertFalse(outcome.removeAfter)
    }

    func testPoisonTickAtPotencyTwoIsMarkedForRemoval() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let poison = ActiveEffect(id: 1, effect: .poison(2), remainingTicks: 0, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(poison, target: battle.enemy, battle: &battle)
        // 2 - max(1, 0) = 1
        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.updatedStack?.effect.potency, 1)
        XCTAssertFalse(outcome.removeAfter)
    }

    func testDefaultTickDecrementsDurationForTickableBuffs() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 5, 6), remainingTicks: 6, sourceActorID: "hero")
        let outcome = EffectHandlersTestSupport.dispatchTick(shield, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.events.isEmpty)
        XCTAssertEqual(outcome.updatedStack?.remainingTicks, 5)
        XCTAssertFalse(outcome.removeAfter)
    }
}
