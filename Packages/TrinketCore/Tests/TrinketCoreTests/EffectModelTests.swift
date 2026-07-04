import TrinketCore
import XCTest

final class EffectModelTests: XCTestCase {
    func testRepresentativeEffectSummariesAndProperties() {
        XCTAssertEqual(Effect.burn(4).summary, "applies Burning")
        XCTAssertEqual(Effect.burn(4).potencyAfterTick(), 2)
        XCTAssertTrue(Effect.bleed(3).isBleed)
        XCTAssertEqual(Effect.instantHeal(.health, 5).summary, "restore 5 Health")
        XCTAssertTrue(Effect.instantHeal(.health, 5).isInstant)
        XCTAssertEqual(Effect.cleanse(nil).summary, "cleanse all debuffs")
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
