import Testing
import TrinketCore

struct EffectModelTests {
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

    @Test func `effect arithmetic saturates at integer limits`() {
        let empowered = DamageComponent(
            Int.max,
            keyword: .burn,
            bonusAmount: Int.max,
        ).withManaEmpowerment()
        #expect(empowered.amount == Int.max)
        #expect(empowered.bonusAmount == Int.max)
        #expect(Effect.burn(Int.max).withManaEmpowerment() == .burn(Int.max))
        #expect(
            Effect.recurringDamage(.freeze, Int.max, 2).withManaEmpowerment()
                == .recurringDamage(.freeze, Int.max, 2),
        )

        #expect(DamageComponent(Int.max, bonusAmount: 1).hasPotentialDamage)
        #expect(!DamageComponent(Int.min, bonusAmount: -1).hasPotentialDamage)
        #expect(!DamageComponent(-2, bonusAmount: 2).hasPotentialDamage)

        #expect(Effect.poisonDecayAmount(for: 8) == 2)
        #expect(Effect.poisonDecayAmount(for: Int.max) == Int.max / 4)
        #expect(Effect.poisonDecayAmount(for: Int.min) == 1)
        #expect(Effect.poison(Int.min).potencyAfterTurn() == 0)
    }

    @Test func `burn decay clamps negative inputs and underflow to zero`() {
        #expect(Effect.burn(0).potencyAfterTurn() == 0)
        #expect(Effect.burn(-5).potencyAfterTurn() == 0)
        #expect(Effect.burn(Int.min).potencyAfterTurn() == 0)
    }

    @Test func `slowed burn and poison exhaust instead of stalling detonation`() {
        #expect(Effect.burn(8).potencyAfterTurn() == 4)
        #expect(Effect.burn(8).potencyAfterTurn(burnDecaySlowPercent: 0.25) == 5)
        #expect(Effect.poison(8).potencyAfterTurn() == 6)
        #expect(Effect.poison(8).potencyAfterTurn(poisonDecaySlowPercent: 0.25) == 6)

        for slowPercent in [0.55, 1.0] {
            for initial in [Effect.burn(8), .poison(8)] {
                var effect = initial
                for _ in 0 ..< 8 {
                    let next = effect.potencyAfterTurn(
                        burnDecaySlowPercent: slowPercent,
                        poisonDecaySlowPercent: slowPercent,
                    )
                    effect = Effect.decayingDoT(keyword: effect.keyword, potency: next)
                }
                #expect(effect.potency == 0)
            }
        }
    }
}
