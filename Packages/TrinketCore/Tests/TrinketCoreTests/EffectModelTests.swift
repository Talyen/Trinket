import TrinketCore
import Testing

@Suite
struct EffectModelTests {
    @Test func representativeEffectSummariesAndProperties() {
        #expect(Effect.burn(4).summary == "applies Burning")
        #expect(Effect.burn(4).potencyAfterTick() == 2)
        #expect(Effect.bleed(3).isBleed)
        #expect(Effect.instantHeal(.health, 5).summary == "restore 5 Health")
        #expect(Effect.instantHeal(.health, 5).isInstant)
        #expect(Effect.cleanse(nil).summary == "cleanse all debuffs")
    }

    @Test func activeEffectTracksRemainingTicks() {
        let effect = Effect.bleed(3)
        var active = ActiveEffect(id: 1, effect: effect, remainingTicks: 3)
        #expect(active.keyword == .bleed)
        #expect(active.remainingTicks == 3)
        active.remainingTicks -= 1
        #expect(active.remainingTicks == 2)
    }

    @Test func effectKindMatchesCase() {
        #expect(Effect.burn(3).kind == .burn)
        #expect(Effect.poison(2).kind == .poison)
        #expect(Effect.bleed(1).kind == .bleed)
        #expect(Effect.controlMeter(.stun, 1, 10).kind == .controlMeter)
        #expect(Effect.shield(.block, 1, 6).kind == .shield)
        #expect(Effect.mitigation(.armor, 0.25, 6).kind == .mitigation)
        #expect(Effect.instantHeal(.health, 1).kind == .instantHeal)
        #expect(Effect.leech(.leech, 0.1, 6).kind == .leech)
        #expect(Effect.resourceGain(.gold, 1).kind == .resourceGain)
        #expect(Effect.resourceGain(.mana, 1).kind == .resourceGain)
        #expect(Effect.cleanse(.poison).kind == .cleanse)
        #expect(Effect.cleanse(nil).kind == .cleanse)
        #expect(Effect.cleanseRandom.kind == .cleanseRandom)
        #expect(Effect.purge(.block).kind == .purge)
        #expect(Effect.purge(nil).kind == .purge)
        #expect(Effect.purgeRandom.kind == .purgeRandom)
        #expect(Effect.halveMitigation(.armor).kind == .halveMitigation)
        #expect(Effect.haste(4).kind == .haste)
        #expect(Effect.thorns(.physical, 1, 6).kind == .thorns)
        #expect(Effect.marked(2, 6).kind == .marked)
        #expect(Effect.criticalChanceBonus(0.1, 6).kind == .criticalChanceBonus)
        #expect(Effect.restoreManaOnHit(1, 6).kind == .restoreManaOnHit)
    }

    @Test func effectKindIsUniquePerCase() {
        #expect(Set(EffectKind.allCases).count == EffectKind.allCases.count)
    }

    @Test func isRemovableDebuffMatchesPriorDefinition() {
        #expect(Effect.burn(1).isRemovableDebuff)
        #expect(Effect.poison(1).isRemovableDebuff)
        #expect(Effect.bleed(1).isRemovableDebuff)
        #expect(Effect.controlMeter(.stun, 1, 10).isRemovableDebuff)
        #expect(!(Effect.shield(.block, 1, 6)).isRemovableDebuff)
        #expect(!(Effect.mitigation(.armor, 0.25, 6)).isRemovableDebuff)
        #expect(!(Effect.leech(.leech, 0.1, 6)).isRemovableDebuff)
        #expect(!(Effect.cleanse(.poison)).isRemovableDebuff)
        #expect(!(Effect.cleanse(nil)).isRemovableDebuff)
        #expect(!(Effect.instantHeal(.health, 1)).isRemovableDebuff)
        #expect(!(Effect.resourceGain(.gold, 1)).isRemovableDebuff)
        #expect(!(Effect.cleanseRandom.isRemovableDebuff))
        #expect(!(Effect.purge(.block)).isRemovableDebuff)
        #expect(!(Effect.purgeRandom.isRemovableDebuff))
        #expect(!(Effect.halveMitigation(.armor)).isRemovableDebuff)
    }

    @Test func isRemovableBuffMatchesDefinition() {
        #expect(Effect.shield(.block, 1, 6).isRemovableBuff)
        #expect(Effect.mitigation(.armor, 0.25, 6).isRemovableBuff)
        #expect(Effect.leech(.leech, 0.1, 6).isRemovableBuff)
        #expect(!(Effect.burn(1)).isRemovableBuff)
        #expect(!(Effect.poison(1)).isRemovableBuff)
        #expect(!(Effect.controlMeter(.stun, 1, 10)).isRemovableBuff)
    }

    @Test func isTickableMatchesPriorDefinition() {
        #expect(Effect.burn(1).isTickable)
        #expect(Effect.poison(1).isTickable)
        #expect(Effect.bleed(1).isTickable)
        #expect(Effect.controlMeter(.stun, 1, 10).isTickable)
        #expect(Effect.shield(.block, 1, 6).isTickable)
        #expect(Effect.mitigation(.armor, 0.25, 6).isTickable)
        #expect(Effect.leech(.leech, 0.1, 6).isTickable)
        #expect(!(Effect.instantHeal(.health, 1)).isTickable)
        #expect(!(Effect.resourceGain(.gold, 1)).isTickable)
        #expect(!(Effect.cleanse(.poison)).isTickable)
        #expect(!(Effect.cleanse(nil)).isTickable)
        #expect(!(Effect.cleanseRandom.isTickable))
        #expect(!(Effect.purge(.block)).isTickable)
        #expect(!(Effect.purgeRandom.isTickable))
        #expect(!(Effect.halveMitigation(.armor)).isTickable)
    }
}
