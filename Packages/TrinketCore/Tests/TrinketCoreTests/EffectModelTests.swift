import Testing
import TrinketCore

struct EffectModelTests {
    @Test func representativeEffectProperties() throws {
        try #expect(Effect.burn(4).potencyAfterTurn() == 2)
        try #expect(Effect.bleed(3).isBleed)
        try #expect(Effect.instantHeal(.health, 5).isInstant)
        try #expect(Effect.drawCards(2).isInstant)
    }

    @Test func avatarEffectModelsSelfBuffPulse() throws {
        let avatar = Effect.avatar(holyDamage: 6, blockPerTurn: 4, turns: 1)
        try #expect(avatar.keyword == .holy)
        try #expect(avatar.potency == 6)
        try #expect(avatar.durationTurns == 1)
        try #expect(avatar.advancesEachTurn)
        try #expect(avatar.isRemovableBuff)
        try #expect(!avatar.isRemovableDebuff)
        try #expect(!avatar.isInstant)
        try #expect(!avatar.isDecayingDoT)
        try #expect(!avatar.isManaEmpowerableBurnOrFreezeDamage)
        try #expect(avatar.withManaEmpowerment() == avatar)
        try #expect(Effect.defaultTarget(for: avatar) == .actor)
        try #expect(avatar.kind == .avatar)
    }

    @Test func manaEmpowermentRaisesBurnAndFreezeDamageNumbersOnly() throws {
        try #expect(Effect.burn(2).isManaEmpowerableBurnOrFreezeDamage)
        try #expect(Effect.recurringDamage(.freeze, 2, 2).isManaEmpowerableBurnOrFreezeDamage)
        try #expect(!Effect.poison(2).isManaEmpowerableBurnOrFreezeDamage)
        try #expect(!Effect.multiplyDoT(.burn, 2).isManaEmpowerableBurnOrFreezeDamage)
        try #expect(Effect.burn(2).withManaEmpowerment() == .burn(3))
        try #expect(
            Effect.recurringDamage(.freeze, 2, 2).withManaEmpowerment()
                == .recurringDamage(.freeze, 3, 2)
        )
        try #expect(Effect.poison(2).withManaEmpowerment() == .poison(2))
        try #expect(DamageComponent(2, keyword: .burn).withManaEmpowerment().amount == 3)
        try #expect(DamageComponent(2, keyword: .physical).withManaEmpowerment().amount == 2)
        let empoweredBonus = DamageComponent(
            4,
            keyword: .burn,
            bonusAmount: 4,
            condition: .enemyBurning
        ).withManaEmpowerment()
        try #expect(empoweredBonus.amount == 5)
        try #expect(empoweredBonus.bonusAmount == 5)
    }

    @Test func effectClassificationFlagsMatchDefinitions() throws {
        try #expect(Effect.burn(1).isRemovableDebuff)
        try #expect(Effect.poison(1).isRemovableDebuff)
        try #expect(Effect.bleed(1).isRemovableDebuff)
        try #expect(Effect.controlMeter(.stun, 1, 10).isRemovableDebuff)
        try #expect(!(Effect.shield(.block, 1)).isRemovableDebuff)
        try #expect(!(Effect.cleanse(.poison)).isRemovableDebuff)
        try #expect(!(Effect.cleanse(nil)).isRemovableDebuff)
        try #expect(!(Effect.instantHeal(.health, 1)).isRemovableDebuff)
        try #expect(!(Effect.resourceGain(.gold, 1)).isRemovableDebuff)
        try #expect(!(Effect.cleanseRandom.isRemovableDebuff))
        try #expect(!(Effect.purge(.block)).isRemovableDebuff)
        try #expect(!(Effect.purgeRandom.isRemovableDebuff))
        try #expect(!(Effect.halveShield(.block)).isRemovableDebuff)

        try #expect(Effect.shield(.block, 1).isRemovableBuff)
        try #expect(!(Effect.burn(1)).isRemovableBuff)
        try #expect(!(Effect.poison(1)).isRemovableBuff)
        try #expect(!(Effect.controlMeter(.stun, 1, 10)).isRemovableBuff)

        try #expect(Effect.burn(1).advancesEachTurn)
        try #expect(Effect.poison(1).advancesEachTurn)
        try #expect(Effect.bleed(1).advancesEachTurn)
        try #expect(Effect.controlMeter(.stun, 1, 10).advancesEachTurn)
        try #expect(!(Effect.shield(.block, 1)).advancesEachTurn)
        try #expect(!(Effect.nextHolyStrike.advancesEachTurn))
        try #expect(!(Effect.nextStrikeDouble.advancesEachTurn))
        try #expect(!(Effect.evadeNextHit.advancesEachTurn))
        try #expect(Effect.nextStrikeDouble.isRemovableBuff)
        try #expect(Effect.evadeNextHit.isRemovableBuff)
        try #expect(!(Effect.instantHeal(.health, 1)).advancesEachTurn)
        try #expect(!(Effect.resourceGain(.gold, 1)).advancesEachTurn)
        try #expect(!(Effect.cleanse(.poison)).advancesEachTurn)
        try #expect(!(Effect.cleanse(nil)).advancesEachTurn)
        try #expect(!(Effect.cleanseRandom.advancesEachTurn))
        try #expect(!(Effect.purge(.block)).advancesEachTurn)
        try #expect(!(Effect.purgeRandom.advancesEachTurn))
        try #expect(!(Effect.halveShield(.block)).advancesEachTurn)
    }
}
