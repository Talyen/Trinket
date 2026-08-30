import Testing
import TrinketCore

struct EffectModelTests {
    @Test func `representative effect properties`() throws {
        try #expect(Effect.burn(4).potencyAfterTurn() == 2)
        try #expect(Effect.bleed(3).isBleed)
        try #expect(Effect.instantHeal(.health, 5).isInstant)
        try #expect(Effect.drawCards(2).isInstant)
    }

    @Test func `avatar effect models self buff pulse`() throws {
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

    @Test func `damage and strength reduction default to ability target`() {
        #expect(Effect.defaultTarget(for: .damageReductionPercent(0.25, 2)) == .abilityTarget)
        #expect(Effect.defaultTarget(for: .damageReductionFlat(3, 1)) == .abilityTarget)
        #expect(Effect.defaultTarget(for: .strengthReduction(2, 3)) == .abilityTarget)
    }

    @Test func `mana empowerment raises burn and freeze damage numbers only`() throws {
        try #expect(Effect.burn(2).isManaEmpowerableBurnOrFreezeDamage)
        try #expect(Effect.recurringDamage(.freeze, 2, 2).isManaEmpowerableBurnOrFreezeDamage)
        try #expect(!Effect.poison(2).isManaEmpowerableBurnOrFreezeDamage)
        try #expect(!Effect.multiplyDoT(.burn, 2).isManaEmpowerableBurnOrFreezeDamage)
        try #expect(Effect.burn(2).withManaEmpowerment() == .burn(3))
        try #expect(
            Effect.recurringDamage(.freeze, 2, 2).withManaEmpowerment()
                == .recurringDamage(.freeze, 3, 2),
        )
        try #expect(Effect.poison(2).withManaEmpowerment() == .poison(2))
        try #expect(DamageComponent(2, keyword: .burn).withManaEmpowerment().amount == 3)
        try #expect(DamageComponent(2, keyword: .physical).withManaEmpowerment().amount == 2)
        let empoweredBonus = DamageComponent(
            4,
            keyword: .burn,
            bonusAmount: 4,
            condition: .enemyBurning,
        ).withManaEmpowerment()
        try #expect(empoweredBonus.amount == 5)
        try #expect(empoweredBonus.bonusAmount == 5)
    }

    @Test func `effect classification flags match definitions`() throws {
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

    @Test func `every effect kind has behavior metadata`() {
        for kind in EffectKind.allCases {
            _ = EffectMetadata.behavior(for: kind)
        }
    }

    @Test func `representative effects have non empty apply phrases`() {
        let sampleEffects: [Effect] = [
            .burn(2),
            .poison(3),
            .bleed(4),
            .controlMeter(.stun, 2, 6),
            .shield(.block, 4),
            .shield(.holy, 4),
            .instantHeal(.health, 5),
            .instantHeal(.holy, 5),
            .resourceGain(.gold, 10),
            .resourceGain(.mana, 2),
            .resourceGain(.holy, 1),
            .drawCards(1),
            .drawCards(3),
            .drawAndPlayCards(1),
            .drawAndPlayCards(2),
            .cleanse(.poison),
            .cleanse(nil),
            .cleanseHealPerDebuff(2),
            .cleanseRandom,
            .purge(.block),
            .purge(nil),
            .purgeRandom,
            .halveShield(.block),
            .halveShield(.holy),
            .deathsDoor,
            .thorns(2),
            .marked(2, 6),
            .criticalChanceBonus(0.25, 2),
            .restoreManaOnHit(1, 2),
            .damageKeywordOverride(.holy, 2, 2),
            .nextHolyStrike,
            .nextStrikeDouble,
            .evadeNextHit,
            .convertManaToBlock,
            .shieldFromMana,
            .shieldFromHalfMana,
            .shieldFromGold(goldPerBlock: 5),
            .maximumManaBonus(2),
            .nextStrikeCritical,
            .freezeNextAttacker,
            .onHitDamage(.holy, 3),
            .multiplyDoT(.burn, 2),
            .multiplyDoT(.poison, 3),
            .recurringDamage(.freeze, 3, 2),
            .avatar(holyDamage: 6, blockPerTurn: 4, turns: 2),
            .revive(10),
            .damageReductionPercent(0.20, 2),
            .damageReductionFlat(3, 2),
            .strengthReduction(2, 2),
            .hemorrhage(5),
        ]
        for effect in sampleEffects {
            #expect(!EffectPresentation.applyPhrase(for: effect).isEmpty, "\(effect) should have non-empty phrase")
        }
    }

    @Test func `flag effect summary phrases are registered`() {
        for kind in [EffectKind.nextHolyStrike, .nextStrikeDouble, .evadeNextHit, .nextStrikeCritical, .freezeNextAttacker] {
            #expect(!EffectMetadata.requiredBattleSummaryPhrase(for: kind).isEmpty)
            #expect(EffectMetadata.battleSummaryPhrase(for: kind) != nil)
        }
        #expect(EffectMetadata.battleSummaryPhrase(for: .burn) == nil)
    }
}
