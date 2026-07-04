import Foundation
import TrinketCore
import TrinketContent

enum LoadoutDamageClassifier {
    static func dealsEnemyDamage(_ ability: Ability) -> Bool {
        ability.directDamage > 0
    }
}

public enum AbilityLoadoutSampler {
    public static let maxNonDamageAcrossPair = 3
    public static let preferredDamageAcrossPair = 3

    public static func defaultLoadout(
        for combatant: Combatant,
        progression: CombatantProgression
    ) -> AbilityLoadout {
        var rng = SeededRandomNumberGenerator(seed: 0)
        return damageBiasedLoadout(for: combatant, progression: progression, using: &rng)
    }

    public static func defaultLoadoutPair(
        hero: Combatant,
        pet: Combatant,
        progression: CombatantProgression
    ) -> (AbilityLoadout, AbilityLoadout) {
        var rng = SeededRandomNumberGenerator(seed: 0)
        return constrainedLoadoutPair(
            hero: hero,
            pet: pet,
            progression: progression,
            using: &rng,
            randomize: false
        )
    }

    public static func randomLoadout<RNG: RandomNumberGenerator>(
        for combatant: Combatant,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG
    ) -> AbilityLoadout {
        let choices = combatant.abilityChoices
        let basic = pickAbility(
            from: choices.basics,
            tier: .basic,
            progression: progression,
            preferDamage: false,
            using: &randomNumberGenerator
        )
        let skill = pickAbility(
            from: choices.skills,
            tier: .skill,
            progression: progression,
            preferDamage: false,
            using: &randomNumberGenerator
        )
        let ultimate = pickAbility(
            from: choices.ultimates,
            tier: .ultimate,
            progression: progression,
            preferDamage: false,
            using: &randomNumberGenerator
        )
        return AbilityLoadout(basic: basic, skill: skill, ultimate: ultimate)
    }

    public static func randomLoadoutPair<RNG: RandomNumberGenerator>(
        hero: Combatant,
        pet: Combatant,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG
    ) -> (AbilityLoadout, AbilityLoadout) {
        constrainedLoadoutPair(
            hero: hero,
            pet: pet,
            progression: progression,
            using: &randomNumberGenerator,
            randomize: true
        )
    }

    public static func loadout(
        for combatant: Combatant,
        selecting ability: Ability,
        progression: CombatantProgression
    ) -> AbilityLoadout {
        let base = defaultLoadout(for: combatant, progression: progression)
        return base.selecting(ability).unlocked(for: progression)
    }

    static func satisfiesDamageBudget(
        hero: AbilityLoadout,
        pet: AbilityLoadout,
        heroCombatant: Combatant,
        petCombatant: Combatant,
        progression: CombatantProgression
    ) -> Bool {
        let counts = damageCounts(hero: hero, pet: pet, progression: progression)
        guard counts.damage > 0 else { return false }
        guard counts.nonDamage <= maxNonDamageAcrossPair else { return false }
        return counts.damage >= minimumDamageCount(
            heroCombatant: heroCombatant,
            petCombatant: petCombatant,
            progression: progression
        )
    }

    private static func constrainedLoadoutPair<RNG: RandomNumberGenerator>(
        hero: Combatant,
        pet: Combatant,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG,
        randomize: Bool
    ) -> (AbilityLoadout, AbilityLoadout) {
        var heroLoadout: AbilityLoadout
        var petLoadout: AbilityLoadout

        if randomize {
            heroLoadout = randomLoadout(for: hero, progression: progression, using: &randomNumberGenerator)
            petLoadout = randomLoadout(for: pet, progression: progression, using: &randomNumberGenerator)
        } else {
            heroLoadout = damageBiasedLoadout(for: hero, progression: progression, using: &randomNumberGenerator)
            petLoadout = damageBiasedLoadout(for: pet, progression: progression, using: &randomNumberGenerator)
        }

        applyDamageBudgetCorrections(
            hero: &heroLoadout,
            pet: &petLoadout,
            heroCombatant: hero,
            petCombatant: pet,
            progression: progression,
            using: &randomNumberGenerator
        )
        return (heroLoadout, petLoadout)
    }

    private static func damageBiasedLoadout<RNG: RandomNumberGenerator>(
        for combatant: Combatant,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG
    ) -> AbilityLoadout {
        let choices = combatant.abilityChoices
        let basic = pickAbility(
            from: choices.basics,
            tier: .basic,
            progression: progression,
            preferDamage: true,
            using: &randomNumberGenerator
        )
        let skill = pickAbility(
            from: choices.skills,
            tier: .skill,
            progression: progression,
            preferDamage: true,
            using: &randomNumberGenerator
        )
        let ultimate = pickAbility(
            from: choices.ultimates,
            tier: .ultimate,
            progression: progression,
            preferDamage: true,
            using: &randomNumberGenerator
        )
        return AbilityLoadout(basic: basic, skill: skill, ultimate: ultimate)
    }

    private static func pickAbility<RNG: RandomNumberGenerator>(
        from choices: [Ability],
        tier: AbilityTier,
        progression: CombatantProgression,
        preferDamage: Bool,
        using randomNumberGenerator: inout RNG
    ) -> Ability? {
        guard progression.unlocks(tier), !choices.isEmpty else { return nil }
        if preferDamage {
            let damageChoices = choices.filter(LoadoutDamageClassifier.dealsEnemyDamage)
            if let pick = damageChoices.randomElement(using: &randomNumberGenerator) {
                return pick
            }
        }
        return choices.randomElement(using: &randomNumberGenerator)
    }

    private static func applyDamageBudgetCorrections<RNG: RandomNumberGenerator>(
        hero: inout AbilityLoadout,
        pet: inout AbilityLoadout,
        heroCombatant: Combatant,
        petCombatant: Combatant,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG
    ) {
        for _ in 0 ..< 12 {
            if satisfiesDamageBudget(
                hero: hero,
                pet: pet,
                heroCombatant: heroCombatant,
                petCombatant: petCombatant,
                progression: progression
            ) {
                return
            }

            let counts = damageCounts(hero: hero, pet: pet, progression: progression)
            if counts.damage < minimumDamageCount(
                heroCombatant: heroCombatant,
                petCombatant: petCombatant,
                progression: progression
            ) || counts.nonDamage > maxNonDamageAcrossPair {
                if replaceWithDamageAbility(
                    in: &hero,
                    combatant: heroCombatant,
                    progression: progression,
                    using: &randomNumberGenerator
                ) { continue }
                _ = replaceWithDamageAbility(
                    in: &pet,
                    combatant: petCombatant,
                    progression: progression,
                    using: &randomNumberGenerator
                )
            }
        }
    }

    private static func replaceWithDamageAbility<RNG: RandomNumberGenerator>(
        in loadout: inout AbilityLoadout,
        combatant: Combatant,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG
    ) -> Bool {
        let tiers = AbilityTier.allCases.filter { progression.unlocks($0) }.shuffled(using: &randomNumberGenerator)

        for tier in tiers {
            guard let current = loadout.ability(for: tier),
                  !LoadoutDamageClassifier.dealsEnemyDamage(current)
            else { continue }
            let choices = combatant.abilityChoices.abilities(for: tier).filter(LoadoutDamageClassifier.dealsEnemyDamage)
            guard let replacement = choices.randomElement(using: &randomNumberGenerator) else { continue }
            loadout = loadout.selecting(replacement)
            return true
        }
        return false
    }

    private static func minimumDamageCount(
        heroCombatant: Combatant,
        petCombatant: Combatant,
        progression: CombatantProgression
    ) -> Int {
        let slots = unlockedSlotCount(for: progression)
        let available = availableDamageSlotCount(
            hero: heroCombatant,
            pet: petCombatant,
            progression: progression
        )
        let desired: Int
        if slots >= 6 {
            desired = preferredDamageAcrossPair
        } else if slots >= 4 {
            desired = 2
        } else {
            desired = 1
        }
        return min(desired, max(1, available))
    }

    private static func availableDamageSlotCount(
        hero: Combatant,
        pet: Combatant,
        progression: CombatantProgression
    ) -> Int {
        var count = 0
        for combatant in [hero, pet] {
            for tier in AbilityTier.allCases where progression.unlocks(tier) {
                if combatant.abilityChoices.abilities(for: tier).contains(where: LoadoutDamageClassifier.dealsEnemyDamage) {
                    count += 1
                }
            }
        }
        return count
    }

    private static func unlockedSlotCount(for progression: CombatantProgression) -> Int {
        AbilityTier.allCases.filter { progression.unlocks($0) }.count * 2
    }

    private static func damageCounts(
        hero: AbilityLoadout,
        pet: AbilityLoadout,
        progression: CombatantProgression
    ) -> (damage: Int, nonDamage: Int) {
        let abilities = hero.unlocked(for: progression).abilities + pet.unlocked(for: progression).abilities
        let damage = abilities.filter(LoadoutDamageClassifier.dealsEnemyDamage).count
        return (damage, abilities.count - damage)
    }
}
