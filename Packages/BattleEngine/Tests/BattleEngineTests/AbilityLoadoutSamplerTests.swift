import Testing
@testable import BalanceSweepCLI
import TrinketCore
import TrinketContent

@Suite
struct AbilityLoadoutSamplerTests {
    @Test func randomLoadoutPairLimitsNonDamageAbilitiesAcrossHeroAndPet() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "alchemist" })
        let pet = try #require(GameContent.pets.first { $0.id == "golden_retriever" })
        let progression = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)

        for seed in 0 ..< 32 {
            var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
            let (heroLoadout, petLoadout) = AbilityLoadoutSampler.randomLoadoutPair(
                hero: hero,
                pet: pet,
                progression: progression,
                using: &rng
            )

            #expect(
                AbilityLoadoutSampler.satisfiesDamageBudget(
                    hero: heroLoadout,
                    pet: petLoadout,
                    heroCombatant: hero,
                    petCombatant: pet,
                    progression: progression
                )
            )
        }
    }

    @Test func defaultLoadoutPairPrefersDamageForSupportCombatants() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "alchemist" })
        let pet = try #require(GameContent.pets.first { $0.id == "golden_retriever" })
        let progression = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)

        let (heroLoadout, petLoadout) = AbilityLoadoutSampler.defaultLoadoutPair(
            hero: hero,
            pet: pet,
            progression: progression
        )

        #expect(
            AbilityLoadoutSampler.satisfiesDamageBudget(
                hero: heroLoadout,
                pet: petLoadout,
                heroCombatant: hero,
                petCombatant: pet,
                progression: progression
            )
        )
        #expect(
            (heroLoadout.abilities + petLoadout.abilities).filter { $0.directDamage > 0 }.count >= 2
        )
    }
}
