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

    func testAbilityUsesGeneratedDescription() {
        let ability = Ability.rayOfFrost
        XCTAssertEqual(ability.summary, "Deal 1 Freeze damage.")
    }

    func testAbilityHealHasNoDamage() {
        XCTAssertEqual(Ability.heal.summary, "Restore 3 Health.")
        XCTAssertEqual(Ability.heal.directDamage, 0)
    }

    // MARK: - EffectKind

    func testEffectKindMatchesCase() {
        XCTAssertEqual(Effect.burn(3).kind, .burn)
        XCTAssertEqual(Effect.poison(2).kind, .poison)
        XCTAssertEqual(Effect.bleed(1).kind, .bleed)
        XCTAssertEqual(Effect.prevention(.stun, 1).kind, .prevention)
        XCTAssertEqual(Effect.preventionBuildup(.freeze, 1, 10).kind, .preventionBuildup)
        XCTAssertEqual(Effect.shield(.block, 1, 6).kind, .shield)
        XCTAssertEqual(Effect.mitigation(.armor, 0.25, 6).kind, .mitigation)
        XCTAssertEqual(Effect.instantHeal(.health, 1).kind, .instantHeal)
        XCTAssertEqual(Effect.leech(.leech, 0.1, 6).kind, .leech)
        XCTAssertEqual(Effect.resourceGain(.gold, 1).kind, .resourceGain)
        XCTAssertEqual(Effect.cleanse(.poison, 0).kind, .cleanse)
        XCTAssertEqual(Effect.cleanse(nil, 0).kind, .cleanse)
        XCTAssertEqual(Effect.cleanseRandom.kind, .cleanseRandom)
        XCTAssertEqual(Effect.dealDamage(.physical, 1).kind, .dealDamage)
        XCTAssertEqual(Effect.halveMitigation(.armor).kind, .halveMitigation)
        XCTAssertEqual(Effect.dodge(.dodge, 3).kind, .dodge)
    }

    func testEffectKindIsUniquePerCase() {
        // New Effect cases must add a matching EffectKind case.
        let allKinds = Set<EffectKind>([
            .burn, .poison, .bleed, .prevention, .preventionBuildup,
            .shield, .mitigation, .instantHeal, .leech, .resourceGain,
            .cleanse, .cleanseRandom, .dealDamage, .halveMitigation, .dodge
        ])
        XCTAssertEqual(allKinds.count, 15)
    }

    // MARK: - isRemovableDebuff

    func testIsRemovableDebuffMatchesPriorDefinition() {
        // debuffs
        XCTAssertTrue(Effect.burn(1).isRemovableDebuff)
        XCTAssertTrue(Effect.poison(1).isRemovableDebuff)
        XCTAssertTrue(Effect.bleed(1).isRemovableDebuff)
        XCTAssertTrue(Effect.prevention(.stun, 1).isRemovableDebuff)
        XCTAssertTrue(Effect.preventionBuildup(.stun, 1, 10).isRemovableDebuff)
        // non-debuffs
        XCTAssertFalse(Effect.shield(.block, 1, 6).isRemovableDebuff)
        XCTAssertFalse(Effect.mitigation(.armor, 0.25, 6).isRemovableDebuff)
        XCTAssertFalse(Effect.leech(.leech, 0.1, 6).isRemovableDebuff)
        XCTAssertFalse(Effect.cleanse(.poison, 0).isRemovableDebuff)
        XCTAssertFalse(Effect.cleanse(nil, 0).isRemovableDebuff)
        XCTAssertFalse(Effect.dodge(.dodge, 3).isRemovableDebuff)
        XCTAssertFalse(Effect.instantHeal(.health, 1).isRemovableDebuff)
        XCTAssertFalse(Effect.resourceGain(.gold, 1).isRemovableDebuff)
        XCTAssertFalse(Effect.dealDamage(.physical, 1).isRemovableDebuff)
        XCTAssertFalse(Effect.cleanseRandom.isRemovableDebuff)
        XCTAssertFalse(Effect.halveMitigation(.armor).isRemovableDebuff)
    }

    // MARK: - isTickable

    func testIsTickableMatchesPriorDefinition() {
        // ticking effects
        XCTAssertTrue(Effect.burn(1).isTickable)
        XCTAssertTrue(Effect.poison(1).isTickable)
        XCTAssertTrue(Effect.bleed(1).isTickable)
        XCTAssertTrue(Effect.prevention(.stun, 1).isTickable)
        XCTAssertTrue(Effect.preventionBuildup(.stun, 1, 10).isTickable)
        XCTAssertTrue(Effect.shield(.block, 1, 6).isTickable)
        XCTAssertTrue(Effect.mitigation(.armor, 0.25, 6).isTickable)
        XCTAssertTrue(Effect.leech(.leech, 0.1, 6).isTickable)
        XCTAssertTrue(Effect.cleanse(.poison, 0).isTickable)
        XCTAssertTrue(Effect.cleanse(nil, 0).isTickable)
        XCTAssertTrue(Effect.dodge(.dodge, 3).isTickable)
        // instant effects
        XCTAssertFalse(Effect.instantHeal(.health, 1).isTickable)
        XCTAssertFalse(Effect.resourceGain(.gold, 1).isTickable)
        XCTAssertFalse(Effect.dealDamage(.physical, 1).isTickable)
        XCTAssertFalse(Effect.cleanseRandom.isTickable)
        XCTAssertFalse(Effect.halveMitigation(.armor).isTickable)
    }
}
