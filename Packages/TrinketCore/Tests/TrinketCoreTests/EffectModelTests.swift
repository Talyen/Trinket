import Testing
import TrinketCore

struct EffectModelTests {
    @Test func representativeEffectSummariesAndProperties() throws {
        try #expect(Effect.burn(4).summary == "applies Burning")
        try #expect(Effect.burn(4).potencyAfterTick() == 2)
        try #expect(Effect.bleed(3).isBleed)
        try #expect(Effect.instantHeal(.health, 5).summary == "restore 5 Health")
        try #expect(Effect.instantHeal(.health, 5).isInstant)
        try #expect(Effect.cleanse(nil).summary == "cleanse all debuffs")
        try #expect(Effect.drawCards(2).summary == "draw 2 cards")
        try #expect(Effect.drawCards(2).isInstant)
    }

    @Test func pairedDoTMapsDamageKeywordsOnly() throws {
        try #expect(Effect.pairedDoT(keyword: .burn, potency: 3) == .burn(3))
        try #expect(Effect.pairedDoT(keyword: .poison, potency: 2) == .poison(2))
        try #expect(Effect.pairedDoT(keyword: .bleed, potency: 4) == .bleed(4))
        try #expect(Effect.pairedDoT(keyword: .physical, potency: 2) == nil)
        try #expect(Effect.pairedDoT(keyword: .burn, potency: 0) == nil)
    }

    @Test func effectClassificationFlagsMatchDefinitions() throws {
        try #expect(Effect.burn(1).isRemovableDebuff)
        try #expect(Effect.poison(1).isRemovableDebuff)
        try #expect(Effect.bleed(1).isRemovableDebuff)
        try #expect(Effect.controlMeter(.stun, 1, 10).isRemovableDebuff)
        try #expect(!(Effect.shield(.block, 1)).isRemovableDebuff)
        try #expect(!(Effect.leech(.leech, 0.1, 6)).isRemovableDebuff)
        try #expect(!(Effect.cleanse(.poison)).isRemovableDebuff)
        try #expect(!(Effect.cleanse(nil)).isRemovableDebuff)
        try #expect(!(Effect.instantHeal(.health, 1)).isRemovableDebuff)
        try #expect(!(Effect.resourceGain(.gold, 1)).isRemovableDebuff)
        try #expect(!(Effect.cleanseRandom.isRemovableDebuff))
        try #expect(!(Effect.purge(.block)).isRemovableDebuff)
        try #expect(!(Effect.purgeRandom.isRemovableDebuff))
        try #expect(!(Effect.halveShield(.block)).isRemovableDebuff)

        try #expect(Effect.shield(.block, 1).isRemovableBuff)
        try #expect(Effect.leech(.leech, 0.1, 6).isRemovableBuff)
        try #expect(!(Effect.burn(1)).isRemovableBuff)
        try #expect(!(Effect.poison(1)).isRemovableBuff)
        try #expect(!(Effect.controlMeter(.stun, 1, 10)).isRemovableBuff)

        try #expect(Effect.burn(1).isTickable)
        try #expect(Effect.poison(1).isTickable)
        try #expect(Effect.bleed(1).isTickable)
        try #expect(Effect.controlMeter(.stun, 1, 10).isTickable)
        try #expect(!(Effect.shield(.block, 1)).isTickable)
        try #expect(!(Effect.nextHolyStrike.isTickable))
        try #expect(Effect.leech(.leech, 0.1, 6).isTickable)
        try #expect(!(Effect.instantHeal(.health, 1)).isTickable)
        try #expect(!(Effect.resourceGain(.gold, 1)).isTickable)
        try #expect(!(Effect.cleanse(.poison)).isTickable)
        try #expect(!(Effect.cleanse(nil)).isTickable)
        try #expect(!(Effect.cleanseRandom.isTickable))
        try #expect(!(Effect.purge(.block)).isTickable)
        try #expect(!(Effect.purgeRandom.isTickable))
        try #expect(!(Effect.halveShield(.block)).isTickable)
    }
}
