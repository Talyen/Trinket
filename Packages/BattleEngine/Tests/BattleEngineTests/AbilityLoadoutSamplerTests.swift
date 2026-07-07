import XCTest
@testable import BalanceSweepCLI
import TrinketCore
import TrinketContent

final class AbilityLoadoutSamplerTests: XCTestCase {
    func testRandomLoadoutPairLimitsNonDamageAbilitiesAcrossHeroAndPet() throws {
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "alchemist" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "golden_retriever" })
        let progression = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)

        for seed in 0 ..< 32 {
            var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
            let (heroLoadout, petLoadout) = AbilityLoadoutSampler.randomLoadoutPair(
                hero: hero,
                pet: pet,
                progression: progression,
                using: &rng
            )

            XCTAssertTrue(
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

    func testDefaultLoadoutPairPrefersDamageForSupportCombatants() throws {
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "alchemist" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "golden_retriever" })
        let progression = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)

        let (heroLoadout, petLoadout) = AbilityLoadoutSampler.defaultLoadoutPair(
            hero: hero,
            pet: pet,
            progression: progression
        )

        XCTAssertTrue(
            AbilityLoadoutSampler.satisfiesDamageBudget(
                hero: heroLoadout,
                pet: petLoadout,
                heroCombatant: hero,
                petCombatant: pet,
                progression: progression
            )
        )
        XCTAssertGreaterThanOrEqual(
            (heroLoadout.abilities + petLoadout.abilities).filter { $0.directDamage > 0 }.count,
            2
        )
    }
}
