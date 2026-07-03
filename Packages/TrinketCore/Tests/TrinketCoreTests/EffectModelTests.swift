import TrinketCore
import XCTest

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

    func testControlMeterEffect() {
        let effect = Effect.controlMeter(.stun, 3, 10)
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
        let effect = Effect.cleanse(.stun)
        XCTAssertEqual(effect.keyword, .stun)
        XCTAssertEqual(effect.durationTicks, 0)
        XCTAssertTrue(effect.isInstant)
        XCTAssertEqual(effect.summary, "cleanse Stunned")
    }

    func testCleanseAllEffect() {
        let effect = Effect.cleanse(nil)
        XCTAssertEqual(effect.keyword, .health)
        XCTAssertEqual(effect.durationTicks, 0)
        XCTAssertTrue(effect.isInstant)
        XCTAssertEqual(effect.summary, "cleanse all debuffs")
    }

    func testPurgeSpecificEffect() {
        let effect = Effect.purge(.block)
        XCTAssertEqual(effect.keyword, .block)
        XCTAssertEqual(effect.durationTicks, 0)
        XCTAssertTrue(effect.isInstant)
        XCTAssertEqual(effect.summary, "purge Block")
    }

    func testPurgeAllEffect() {
        let effect = Effect.purge(nil)
        XCTAssertEqual(effect.keyword, .purge)
        XCTAssertEqual(effect.durationTicks, 0)
        XCTAssertTrue(effect.isInstant)
        XCTAssertEqual(effect.summary, "purge all buffs")
    }

    func testActiveEffectTracksRemainingTicks() {
        let effect = Effect.bleed(3)
        var active = ActiveEffect(id: 1, effect: effect, remainingTicks: 3)
        XCTAssertEqual(active.keyword, .bleed)
        XCTAssertEqual(active.remainingTicks, 3)
        active.remainingTicks -= 1
        XCTAssertEqual(active.remainingTicks, 2)
    }

    func testEffectKindMatchesCase() {
        XCTAssertEqual(Effect.burn(3).kind, .burn)
        XCTAssertEqual(Effect.poison(2).kind, .poison)
        XCTAssertEqual(Effect.bleed(1).kind, .bleed)
        XCTAssertEqual(Effect.controlMeter(.stun, 1, 10).kind, .controlMeter)
        XCTAssertEqual(Effect.shield(.block, 1, 6).kind, .shield)
        XCTAssertEqual(Effect.mitigation(.armor, 0.25, 6).kind, .mitigation)
        XCTAssertEqual(Effect.instantHeal(.health, 1).kind, .instantHeal)
        XCTAssertEqual(Effect.leech(.leech, 0.1, 6).kind, .leech)
        XCTAssertEqual(Effect.resourceGain(.gold, 1).kind, .resourceGain)
        XCTAssertEqual(Effect.cleanse(.poison).kind, .cleanse)
        XCTAssertEqual(Effect.cleanse(nil).kind, .cleanse)
        XCTAssertEqual(Effect.cleanseRandom.kind, .cleanseRandom)
        XCTAssertEqual(Effect.purge(.block).kind, .purge)
        XCTAssertEqual(Effect.purge(nil).kind, .purge)
        XCTAssertEqual(Effect.purgeRandom.kind, .purgeRandom)
        XCTAssertEqual(Effect.halveMitigation(.armor).kind, .halveMitigation)
        XCTAssertEqual(Effect.dodge(.dodge, 3).kind, .dodge)
    }

    func testEffectKindIsUniquePerCase() {
        XCTAssertEqual(Set(EffectKind.allCases).count, EffectKind.allCases.count)
    }

    func testIsRemovableDebuffMatchesPriorDefinition() {
        XCTAssertTrue(Effect.burn(1).isRemovableDebuff)
        XCTAssertTrue(Effect.poison(1).isRemovableDebuff)
        XCTAssertTrue(Effect.bleed(1).isRemovableDebuff)
        XCTAssertTrue(Effect.controlMeter(.stun, 1, 10).isRemovableDebuff)
        XCTAssertFalse(Effect.shield(.block, 1, 6).isRemovableDebuff)
        XCTAssertFalse(Effect.mitigation(.armor, 0.25, 6).isRemovableDebuff)
        XCTAssertFalse(Effect.leech(.leech, 0.1, 6).isRemovableDebuff)
        XCTAssertFalse(Effect.cleanse(.poison).isRemovableDebuff)
        XCTAssertFalse(Effect.cleanse(nil).isRemovableDebuff)
        XCTAssertFalse(Effect.dodge(.dodge, 3).isRemovableDebuff)
        XCTAssertFalse(Effect.instantHeal(.health, 1).isRemovableDebuff)
        XCTAssertFalse(Effect.resourceGain(.gold, 1).isRemovableDebuff)
        XCTAssertFalse(Effect.cleanseRandom.isRemovableDebuff)
        XCTAssertFalse(Effect.purge(.block).isRemovableDebuff)
        XCTAssertFalse(Effect.purgeRandom.isRemovableDebuff)
        XCTAssertFalse(Effect.halveMitigation(.armor).isRemovableDebuff)
    }

    func testIsRemovableBuffMatchesDefinition() {
        XCTAssertTrue(Effect.shield(.block, 1, 6).isRemovableBuff)
        XCTAssertTrue(Effect.mitigation(.armor, 0.25, 6).isRemovableBuff)
        XCTAssertTrue(Effect.leech(.leech, 0.1, 6).isRemovableBuff)
        XCTAssertTrue(Effect.dodge(.dodge, 3).isRemovableBuff)
        XCTAssertFalse(Effect.burn(1).isRemovableBuff)
        XCTAssertFalse(Effect.poison(1).isRemovableBuff)
        XCTAssertFalse(Effect.controlMeter(.stun, 1, 10).isRemovableBuff)
    }

    func testIsTickableMatchesPriorDefinition() {
        XCTAssertTrue(Effect.burn(1).isTickable)
        XCTAssertTrue(Effect.poison(1).isTickable)
        XCTAssertTrue(Effect.bleed(1).isTickable)
        XCTAssertTrue(Effect.controlMeter(.stun, 1, 10).isTickable)
        XCTAssertTrue(Effect.shield(.block, 1, 6).isTickable)
        XCTAssertTrue(Effect.mitigation(.armor, 0.25, 6).isTickable)
        XCTAssertTrue(Effect.leech(.leech, 0.1, 6).isTickable)
        XCTAssertTrue(Effect.dodge(.dodge, 3).isTickable)
        XCTAssertFalse(Effect.instantHeal(.health, 1).isTickable)
        XCTAssertFalse(Effect.resourceGain(.gold, 1).isTickable)
        XCTAssertFalse(Effect.cleanse(.poison).isTickable)
        XCTAssertFalse(Effect.cleanse(nil).isTickable)
        XCTAssertFalse(Effect.cleanseRandom.isTickable)
        XCTAssertFalse(Effect.purge(.block).isTickable)
        XCTAssertFalse(Effect.purgeRandom.isTickable)
        XCTAssertFalse(Effect.halveMitigation(.armor).isTickable)
    }
}
