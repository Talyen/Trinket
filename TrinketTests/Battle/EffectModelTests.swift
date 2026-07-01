import XCTest
@testable import Trinket

final class EffectModelTests: XCTestCase {
    func testBurnEffect() {
        let effect = Effect.burn(4)
        XCTAssertEqual(effect.keyword, .burn)
        XCTAssertEqual(effect.potency, 4)
        XCTAssertEqual(effect.durationTicks, 0)
        XCTAssertFalse(effect.isInstant)
        XCTAssertTrue(effect.isDecayingDoT)
        XCTAssertEqual(effect.summary, "Deals 4 Burn damage")
        XCTAssertEqual(effect.potencyAfterTick(), 2)
    }

    func testPoisonEffect() {
        let effect = Effect.poison(8)
        XCTAssertEqual(effect.keyword, .poison)
        XCTAssertEqual(effect.potency, 8)
        XCTAssertTrue(effect.isDecayingDoT)
        XCTAssertEqual(effect.summary, "Deals 8 Poison damage")
        XCTAssertEqual(effect.potencyAfterTick(), 6)
    }

    func testBleedEffect() {
        let effect = Effect.bleed(3)
        XCTAssertEqual(effect.keyword, .bleed)
        XCTAssertEqual(effect.potency, 3)
        XCTAssertEqual(effect.durationTicks, Effect.bleedDoTTickCount)
        XCTAssertTrue(effect.isBleed)
        XCTAssertEqual(effect.summary, "Deals 3 Bleed damage")
    }

    func testPreventionEffect() {
        let effect = Effect.prevention(.stun, 2)
        XCTAssertEqual(effect.keyword, .stun)
        XCTAssertEqual(effect.durationTicks, 2)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Stun for 2 actions")
    }

    func testShieldEffect() {
        let effect = Effect.shield(.block, 5, 3)
        XCTAssertEqual(effect.keyword, .block)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Block 5 for 3 ticks")
    }

    func testMitigationEffect() {
        let effect = Effect.mitigation(.armor, 0.25, 3)
        XCTAssertEqual(effect.keyword, .armor)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Armor 25% for 3 ticks")
    }

    func testInstantHealEffect() {
        let effect = Effect.instantHeal(.health, 5)
        XCTAssertEqual(effect.keyword, .health)
        XCTAssertEqual(effect.durationTicks, 0)
        XCTAssertTrue(effect.isInstant)
        XCTAssertEqual(effect.summary, "Health 5")
    }

    func testLeechEffect() {
        let effect = Effect.leech(.leech, 0.25, 3)
        XCTAssertEqual(effect.keyword, .leech)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Leech 25% for 3 ticks")
    }

    func testResourceGainEffect() {
        let effect = Effect.resourceGain(.gold, 3)
        XCTAssertEqual(effect.keyword, .gold)
        XCTAssertEqual(effect.durationTicks, 0)
        XCTAssertTrue(effect.isInstant)
        XCTAssertEqual(effect.summary, "Gold 3")
    }

    func testCleanseSpecificEffect() {
        let effect = Effect.cleanse(.stun, 3)
        XCTAssertEqual(effect.keyword, .stun)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Cleanse Stun for 3 ticks")
    }

    func testCleanseAllEffect() {
        let effect = Effect.cleanse(nil, 3)
        XCTAssertEqual(effect.keyword, .health)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Cleanse all for 3 ticks")
    }

    func testActiveEffectTracksRemainingTicks() {
        let effect = Effect.bleed(3)
        var active = ActiveEffect(id: 1, effect: effect, remainingTicks: 3)
        XCTAssertEqual(active.keyword, .bleed)
        XCTAssertEqual(active.remainingTicks, 3)
        active.remainingTicks -= 1
        XCTAssertEqual(active.remainingTicks, 2)
    }

    func testAbilitySummaryIncludesBurnEffect() {
        let ability = Ability(
            id: "test-dot",
            name: "Test DOT",
            tier: .skill,
            directDamage: 3,
            damageKeyword: .poison,
            effects: [.poison(4)]
        )
        XCTAssertTrue(ability.summary.contains("Deals 4 Poison damage"))
    }

    func testAbilitySummaryWithDirectDamageAndEffect() {
        let ability = Ability(
            id: "test-summary",
            name: "Test",
            tier: .basic,
            directDamage: 2,
            damageKeyword: .holy,
            statusApplication: nil,
            effects: [.burn(2)]
        )
        XCTAssertTrue(ability.summary.contains("2 Holy damage"))
        XCTAssertTrue(ability.summary.contains("Deals 2 Burn damage"))
    }
}
