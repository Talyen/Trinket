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
        XCTAssertEqual(effect.summary, "applies Burning")
        XCTAssertEqual(effect.potencyAfterTick(), 2)
    }

    func testPoisonEffect() {
        let effect = Effect.poison(8)
        XCTAssertEqual(effect.keyword, .poison)
        XCTAssertEqual(effect.potency, 8)
        XCTAssertTrue(effect.isDecayingDoT)
        XCTAssertEqual(effect.summary, "applies Poisoned")
        XCTAssertEqual(effect.potencyAfterTick(), 6)
    }

    func testBleedEffect() {
        let effect = Effect.bleed(3)
        XCTAssertEqual(effect.keyword, .bleed)
        XCTAssertEqual(effect.potency, 3)
        XCTAssertEqual(effect.durationTicks, Effect.bleedDoTTickCount)
        XCTAssertTrue(effect.isBleed)
        XCTAssertEqual(effect.summary, "applies Bleeding")
    }

    func testPreventionEffect() {
        let effect = Effect.prevention(.stun, 2)
        XCTAssertEqual(effect.keyword, .stun)
        XCTAssertEqual(effect.durationTicks, 2)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "applies Stunned")
    }

    func testPreventionBuildupEffect() {
        let effect = Effect.preventionBuildup(.stun, 3, 10)
        XCTAssertEqual(effect.keyword, .stun)
        XCTAssertEqual(effect.durationTicks, 0)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "applies Stun Build-up")
    }

    func testShieldEffect() {
        let effect = Effect.shield(.block, 5, 3)
        XCTAssertEqual(effect.keyword, .block)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "gain Block")
    }

    func testMitigationEffect() {
        let effect = Effect.mitigation(.armor, 0.25, 3)
        XCTAssertEqual(effect.keyword, .armor)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "gain Armor")
    }

    func testInstantHealEffect() {
        let effect = Effect.instantHeal(.health, 5)
        XCTAssertEqual(effect.keyword, .health)
        XCTAssertEqual(effect.durationTicks, 0)
        XCTAssertTrue(effect.isInstant)
        XCTAssertEqual(effect.summary, "restore 5 Health")
    }

    func testLeechEffect() {
        let effect = Effect.standardLeechBuff
        XCTAssertEqual(effect.keyword, .leech)
        XCTAssertEqual(effect.durationTicks, 6)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "gain Leech")
    }

    func testResourceGainEffect() {
        let effect = Effect.resourceGain(.gold, 3)
        XCTAssertEqual(effect.keyword, .gold)
        XCTAssertEqual(effect.durationTicks, 0)
        XCTAssertTrue(effect.isInstant)
        XCTAssertEqual(effect.summary, "gain 3 Gold")
    }

    func testCleanseSpecificEffect() {
        let effect = Effect.cleanse(.stun, 3)
        XCTAssertEqual(effect.keyword, .stun)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "cleanse Stunned")
    }

    func testCleanseAllEffect() {
        let effect = Effect.cleanse(nil, 3)
        XCTAssertEqual(effect.keyword, .health)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "cleanse all debuffs")
    }

    func testActiveEffectTracksRemainingTicks() {
        let effect = Effect.bleed(3)
        var active = ActiveEffect(id: 1, effect: effect, remainingTicks: 3)
        XCTAssertEqual(active.keyword, .bleed)
        XCTAssertEqual(active.remainingTicks, 3)
        active.remainingTicks -= 1
        XCTAssertEqual(active.remainingTicks, 2)
    }

    func testAbilityUsesPlayerFacingDescription() {
        let ability = Ability.rayOfFrost
        XCTAssertEqual(ability.summary, "Deal 1 Freeze damage.")
    }

    func testAbilityHealHasNoDamage() {
        XCTAssertEqual(Ability.heal.summary, "Restore 3 Health.")
        XCTAssertEqual(Ability.heal.directDamage, 0)
    }
}
