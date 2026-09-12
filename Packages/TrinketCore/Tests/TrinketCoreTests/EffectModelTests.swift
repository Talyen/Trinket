import Testing
import TrinketCore

struct EffectModelTests {
    @Test func `representative effect properties`() {
        #expect(Effect.burn(4).potencyAfterTurn() == 2)
        #expect(Effect.bleed(3).isBleed)
        #expect(Effect.instantHeal(.health, 5).isInstant)
        #expect(Effect.drawCards(2).isInstant)
    }

    @Test func `avatar effect models self buff pulse`() {
        let avatar = Effect.avatar(holyDamage: 6, blockPerTurn: 4, turns: 1)
        #expect(avatar.keyword == .holy)
        #expect(avatar.potency == 6)
        #expect(avatar.durationTurns == 1)
        #expect(avatar.advancesEachTurn)
        #expect(avatar.isRemovableBuff)
        #expect(!avatar.isRemovableDebuff)
        #expect(!avatar.isInstant)
        #expect(!avatar.isDecayingDoT)
        #expect(!avatar.isManaEmpowerableBurnOrFreezeDamage)
        #expect(avatar.withManaEmpowerment() == avatar)
        #expect(Effect.defaultTarget(for: avatar) == .actor)
        #expect(avatar.kind == .avatar)
    }

    @Test func `damage and strength reduction default to ability target`() {
        #expect(Effect.defaultTarget(for: .damageReductionPercent(0.25, 2)) == .abilityTarget)
        #expect(Effect.defaultTarget(for: .damageReductionFlat(3, 1)) == .abilityTarget)
    }

    @Test func `zero duration covers instants and indefinite buffs`() {
        #expect(Effect.deathsDoor.durationTurns == 0)
        #expect(Effect.deathsDoor.advancesEachTurn)
        #expect(!Effect.deathsDoor.isInstant)
        #expect(!Effect.deathsDoor.isRemovableDebuff)
        #expect(!Effect.deathsDoor.isRemovableBuff)
        #expect(Effect.hemorrhage(5).durationTurns == 0)
        #expect(Effect.hemorrhage(5).isRemovableDebuff)
        #expect(!Effect.hemorrhage(5).advancesEachTurn)
        #expect(!Effect.hemorrhage(5).isInstant)
        #expect(Effect.maximumManaBonus(2).isInstant)
        #expect(Effect.maximumManaBonus(2).isRemovableBuff)
    }

    @Test func `mana empowerment raises burn and freeze damage numbers only`() {
        #expect(Effect.burn(2).isManaEmpowerableBurnOrFreezeDamage)
        #expect(Effect.recurringDamage(.freeze, 2, 2).isManaEmpowerableBurnOrFreezeDamage)
        #expect(!Effect.poison(2).isManaEmpowerableBurnOrFreezeDamage)
        #expect(!Effect.multiplyDoT(.burn, 2).isManaEmpowerableBurnOrFreezeDamage)
        #expect(Effect.burn(2).withManaEmpowerment() == .burn(3))
        #expect(
            Effect.recurringDamage(.freeze, 2, 2).withManaEmpowerment()
                == .recurringDamage(.freeze, 3, 2),
        )
        #expect(Effect.poison(2).withManaEmpowerment() == .poison(2))
        #expect(DamageComponent(2, keyword: .burn).withManaEmpowerment().amount == 3)
        #expect(DamageComponent(2, keyword: .physical).withManaEmpowerment().amount == 2)
        let empoweredBonus = DamageComponent(
            4,
            keyword: .burn,
            bonusAmount: 4,
            condition: .enemyBurning,
        ).withManaEmpowerment()
        #expect(empoweredBonus.amount == 5)
        #expect(empoweredBonus.bonusAmount == 5)
    }

    @Test func `effect classification flags match definitions`() {
        #expect(Effect.burn(1).isRemovableDebuff)
        #expect(Effect.poison(1).isRemovableDebuff)
        #expect(Effect.bleed(1).isRemovableDebuff)
        #expect(Effect.controlMeter(.stun, 1, 10).isRemovableDebuff)
        #expect(!(Effect.shield(.block, 1)).isRemovableDebuff)
        #expect(!(Effect.cleanse(.poison)).isRemovableDebuff)
        #expect(!(Effect.cleanse(nil)).isRemovableDebuff)
        #expect(!(Effect.instantHeal(.health, 1)).isRemovableDebuff)
        #expect(!(Effect.resourceGain(.gold, 1)).isRemovableDebuff)
        #expect(!(Effect.cleanseRandom.isRemovableDebuff))
        #expect(!(Effect.purge(.block)).isRemovableDebuff)
        #expect(!(Effect.purgeRandom.isRemovableDebuff))
        #expect(!(Effect.halveShield(.block)).isRemovableDebuff)

        #expect(Effect.shield(.block, 1).isRemovableBuff)
        #expect(!(Effect.burn(1)).isRemovableBuff)
        #expect(!(Effect.poison(1)).isRemovableBuff)
        #expect(!(Effect.controlMeter(.stun, 1, 10)).isRemovableBuff)

        #expect(Effect.burn(1).advancesEachTurn)
        #expect(Effect.poison(1).advancesEachTurn)
        #expect(Effect.bleed(1).advancesEachTurn)
        #expect(Effect.controlMeter(.stun, 1, 10).advancesEachTurn)
        #expect(!(Effect.shield(.block, 1)).advancesEachTurn)
        #expect(!(Effect.nextHolyStrike.advancesEachTurn))
        #expect(!(Effect.nextStrikeDouble.advancesEachTurn))
        #expect(!(Effect.evadeNextHit.advancesEachTurn))
        #expect(Effect.nextStrikeDouble.isRemovableBuff)
        #expect(Effect.evadeNextHit.isRemovableBuff)
        #expect(!(Effect.instantHeal(.health, 1)).advancesEachTurn)
        #expect(!(Effect.resourceGain(.gold, 1)).advancesEachTurn)
        #expect(!(Effect.cleanse(.poison)).advancesEachTurn)
        #expect(!(Effect.cleanse(nil)).advancesEachTurn)
        #expect(!(Effect.cleanseRandom.advancesEachTurn))
        #expect(!(Effect.purge(.block)).advancesEachTurn)
        #expect(!(Effect.purgeRandom.advancesEachTurn))
        #expect(!(Effect.halveShield(.block)).advancesEachTurn)
    }

    // swiftlint:disable cyclomatic_complexity - exhaustive kind mapping must reject missing cases at compile time
    private static func representativeEffect(for kind: EffectKind) -> Effect {
        switch kind {
        case .burn: .burn(2)
        case .poison: .poison(3)
        case .bleed: .bleed(4)
        case .controlMeter: .controlMeter(.stun, 2, 6)
        case .shield: .shield(.block, 4)
        case .instantHeal: .instantHeal(.health, 5)
        case .resourceGain: .resourceGain(.gold, 10)
        case .drawCards: .drawCards(1)
        case .drawAndPlayCards: .drawAndPlayCards(1)
        case .cleanse: .cleanse(.poison)
        case .cleanseHealPerDebuff: .cleanseHealPerDebuff(2)
        case .panacea: .panacea(baseHeal: 3, healPerDebuff: 2)
        case .cleanseRandom: .cleanseRandom
        case .purge: .purge(.block)
        case .purgeRandom: .purgeRandom
        case .halveShield: .halveShield(.block)
        case .deathsDoor: .deathsDoor
        case .thorns: .thorns(2)
        case .marked: .marked(2, 6)
        case .criticalChanceBonus: .criticalChanceBonus(0.25, 2)
        case .restoreManaOnHit: .restoreManaOnHit(1, 2)
        case .damageKeywordOverride: .damageKeywordOverride(.holy, 2, 2)
        case .nextHolyStrike: .nextHolyStrike
        case .nextStrikeDouble: .nextStrikeDouble
        case .nextBurnBonus: .nextBurnBonus(1)
        case .evadeNextHit: .evadeNextHit
        case .convertManaToBlock: .convertManaToBlock
        case .shieldFromMana: .shieldFromMana
        case .shieldFromHalfMana: .shieldFromHalfMana
        case .shieldFromGold: .shieldFromGold(goldPerBlock: 5)
        case .maximumManaBonus: .maximumManaBonus(2)
        case .nextStrikeCritical: .nextStrikeCritical
        case .freezeNextAttacker: .freezeNextAttacker
        case .onHitDamage: .onHitDamage(.holy, 3)
        case .multiplyDoT: .multiplyDoT(.burn, 2)
        case .detonateDoT: .detonateDoT(.burn, 2)
        case .recurringDamage: .recurringDamage(.freeze, 3, 2)
        case .blessedAegis: .blessedAegis(block: 4, holyDamage: 4)
        case .avatar: .avatar(holyDamage: 6, blockPerTurn: 4, turns: 2)
        case .revive: .revive(10)
        case .damageReductionPercent: .damageReductionPercent(0.20, 2)
        case .damageReductionFlat: .damageReductionFlat(3, 2)
        case .healingReductionPercent: .healingReductionPercent(0.25, 3)
        case .hemorrhage: .hemorrhage(5)
        }
    }

    // swiftlint:enable cyclomatic_complexity

    @Test func `every effect kind has behavior metadata`() {
        for kind in EffectKind.allCases {
            _ = (kind.isRemovableDebuff, kind.isRemovableBuff, kind.advancesEachTurn, kind.isInstant, kind.isDecayingDoT, kind.isBleed)
            #expect(Self.representativeEffect(for: kind).kind == kind)
        }
    }

    @Test func `every effect kind has a descriptive apply phrase`() {
        for kind in EffectKind.allCases {
            let effect = Self.representativeEffect(for: kind)
            let phrase = EffectPresentation.applyPhrase(for: effect)
            #expect(!phrase.isEmpty)
            #expect(phrase != effect.keyword.rawValue, "\(effect) must describe more than its keyword")
        }
    }

    @Test(arguments: [(3, 2), (7, 4)])
    func `panacea describes base healing and healing per debuff`(baseHeal: Int, healPerDebuff: Int) {
        let effect = Effect.panacea(baseHeal: baseHeal, healPerDebuff: healPerDebuff)
        #expect(
            EffectPresentation.applyPhrase(for: effect)
                == "cleanse all debuffs and restore \(baseHeal) Health plus \(healPerDebuff) Health for each debuff cleansed",
        )
    }

    @Test func `flag effect summary phrases are registered`() {
        for kind in [EffectKind.nextHolyStrike, .nextStrikeDouble, .evadeNextHit, .nextStrikeCritical, .freezeNextAttacker] {
            #expect(!EffectKind.requiredBattleSummaryPhrase(for: kind).isEmpty)
            #expect(EffectKind.battleSummaryPhrase(for: kind) != nil)
        }
        #expect(EffectKind.battleSummaryPhrase(for: .burn) == nil)
    }
}
