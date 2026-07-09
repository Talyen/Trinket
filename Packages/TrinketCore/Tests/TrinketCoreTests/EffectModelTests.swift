import TrinketCore
import Testing

@Suite
struct EffectModelTests {
    @Test func representativeEffectSummariesAndProperties() throws {
        try #expect(Effect.burn(4).summary == "applies Burning")
        try #expect(Effect.burn(4).potencyAfterTick() == 2)
        try #expect(Effect.bleed(3).isBleed)
        try #expect(Effect.instantHeal(.health, 5).summary == "restore 5 Health")
        try #expect(Effect.instantHeal(.health, 5).isInstant)
        try #expect(Effect.cleanse(nil).summary == "cleanse all debuffs")
    }

    @Test func activeEffectTracksRemainingTicks() throws {
        let effect = Effect.bleed(3)
        var active = ActiveEffect(id: 1, effect: effect, remainingTicks: 3)
        try #expect(active.keyword == .bleed)
        try #expect(active.remainingTicks == 3)
        active.remainingTicks -= 1
        try #expect(active.remainingTicks == 2)
    }

    @Test func effectKindMatchesCase() throws {
        try #expect(Effect.burn(3).kind == .burn)
        try #expect(Effect.poison(2).kind == .poison)
        try #expect(Effect.bleed(1).kind == .bleed)
        try #expect(Effect.controlMeter(.stun, 1, 10).kind == .controlMeter)
        try #expect(Effect.shield(.block, 1, 6).kind == .shield)
        try #expect(Effect.mitigation(.armor, 0.25, 6).kind == .mitigation)
        try #expect(Effect.instantHeal(.health, 1).kind == .instantHeal)
        try #expect(Effect.leech(.leech, 0.1, 6).kind == .leech)
        try #expect(Effect.resourceGain(.gold, 1).kind == .resourceGain)
        try #expect(Effect.resourceGain(.mana, 1).kind == .resourceGain)
        try #expect(Effect.cleanse(.poison).kind == .cleanse)
        try #expect(Effect.cleanse(nil).kind == .cleanse)
        try #expect(Effect.cleanseRandom.kind == .cleanseRandom)
        try #expect(Effect.purge(.block).kind == .purge)
        try #expect(Effect.purge(nil).kind == .purge)
        try #expect(Effect.purgeRandom.kind == .purgeRandom)
        try #expect(Effect.halveMitigation(.armor).kind == .halveMitigation)
        try #expect(Effect.haste(4).kind == .haste)
        try #expect(Effect.thorns(.physical, 1, 6).kind == .thorns)
        try #expect(Effect.marked(2, 6).kind == .marked)
        try #expect(Effect.criticalChanceBonus(0.1, 6).kind == .criticalChanceBonus)
        try #expect(Effect.restoreManaOnHit(1, 6).kind == .restoreManaOnHit)
        try #expect(Effect.damageKeywordOverride(.holy, 3, 6).kind == .damageKeywordOverride)
    }

    @Test func effectKindIsUniquePerCase() throws {
        try #expect(Set(EffectKind.allCases).count == EffectKind.allCases.count)
    }

    @Test func isRemovableDebuffMatchesPriorDefinition() throws {
        try #expect(Effect.burn(1).isRemovableDebuff)
        try #expect(Effect.poison(1).isRemovableDebuff)
        try #expect(Effect.bleed(1).isRemovableDebuff)
        try #expect(Effect.controlMeter(.stun, 1, 10).isRemovableDebuff)
        try #expect(!(Effect.shield(.block, 1, 6)).isRemovableDebuff)
        try #expect(!(Effect.mitigation(.armor, 0.25, 6)).isRemovableDebuff)
        try #expect(!(Effect.leech(.leech, 0.1, 6)).isRemovableDebuff)
        try #expect(!(Effect.cleanse(.poison)).isRemovableDebuff)
        try #expect(!(Effect.cleanse(nil)).isRemovableDebuff)
        try #expect(!(Effect.instantHeal(.health, 1)).isRemovableDebuff)
        try #expect(!(Effect.resourceGain(.gold, 1)).isRemovableDebuff)
        try #expect(!(Effect.cleanseRandom.isRemovableDebuff))
        try #expect(!(Effect.purge(.block)).isRemovableDebuff)
        try #expect(!(Effect.purgeRandom.isRemovableDebuff))
        try #expect(!(Effect.halveMitigation(.armor)).isRemovableDebuff)
    }

    @Test func isRemovableBuffMatchesDefinition() throws {
        try #expect(Effect.shield(.block, 1, 6).isRemovableBuff)
        try #expect(Effect.mitigation(.armor, 0.25, 6).isRemovableBuff)
        try #expect(Effect.leech(.leech, 0.1, 6).isRemovableBuff)
        try #expect(!(Effect.burn(1)).isRemovableBuff)
        try #expect(!(Effect.poison(1)).isRemovableBuff)
        try #expect(!(Effect.controlMeter(.stun, 1, 10)).isRemovableBuff)
    }

    @Test func isTickableMatchesPriorDefinition() throws {
        try #expect(Effect.burn(1).isTickable)
        try #expect(Effect.poison(1).isTickable)
        try #expect(Effect.bleed(1).isTickable)
        try #expect(Effect.controlMeter(.stun, 1, 10).isTickable)
        try #expect(Effect.shield(.block, 1, 6).isTickable)
        try #expect(Effect.mitigation(.armor, 0.25, 6).isTickable)
        try #expect(Effect.leech(.leech, 0.1, 6).isTickable)
        try #expect(!(Effect.instantHeal(.health, 1)).isTickable)
        try #expect(!(Effect.resourceGain(.gold, 1)).isTickable)
        try #expect(!(Effect.cleanse(.poison)).isTickable)
        try #expect(!(Effect.cleanse(nil)).isTickable)
        try #expect(!(Effect.cleanseRandom.isTickable))
        try #expect(!(Effect.purge(.block)).isTickable)
        try #expect(!(Effect.purgeRandom.isTickable))
        try #expect(!(Effect.halveMitigation(.armor)).isTickable)
    }
}
