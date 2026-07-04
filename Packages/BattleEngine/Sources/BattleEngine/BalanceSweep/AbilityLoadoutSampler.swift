import Foundation
import TrinketCore
import TrinketContent

public enum AbilityLoadoutSampler {
    public static let maxNonDamageAcrossPair = 3

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
        return balancedLoadoutPair(
            hero: hero,
            pet: pet,
            progression: progression,
            using: &rng
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
            using: &randomNumberGenerator
        )
        let skill = pickAbility(
            from: choices.skills,
            tier: .skill,
            progression: progression,
            using: &randomNumberGenerator
        )
        let ultimate = pickAbility(
            from: choices.ultimates,
            tier: .ultimate,
            progression: progression,
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
        for _ in 0 ..< 24 {
            let heroLoadout = randomLoadout(for: hero, progression: progression, using: &randomNumberGenerator)
            let petLoadout = randomLoadout(for: pet, progression: progression, using: &randomNumberGenerator)
            if satisfiesDamageBudget(hero: heroLoadout, pet: petLoadout, progression: progression) {
                return (heroLoadout, petLoadout)
            }
        }

        return balancedLoadoutPair(
            hero: hero,
            pet: pet,
            progression: progression,
            using: &randomNumberGenerator
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

    private static func balancedLoadoutPair<RNG: RandomNumberGenerator>(
        hero: Combatant,
        pet: Combatant,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG
    ) -> (AbilityLoadout, AbilityLoadout) {
        var heroLoadout = damageBiasedLoadout(
            for: hero,
            progression: progression,
            using: &randomNumberGenerator
        )
        var petLoadout = damageBiasedLoadout(
            for: pet,
            progression: progression,
            using: &randomNumberGenerator
        )

        if satisfiesDamageBudget(hero: heroLoadout, pet: petLoadout, progression: progression) {
            return (heroLoadout, petLoadout)
        }

        rebalanceLoadoutPair(
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
        let basic = pickDamageFirst(
            from: choices.basics,
            tier: .basic,
            progression: progression,
            using: &randomNumberGenerator
        )
        let skill = pickDamageFirst(
            from: choices.skills,
            tier: .skill,
            progression: progression,
            using: &randomNumberGenerator
        )
        let ultimate = pickAbility(
            from: choices.ultimates,
            tier: .ultimate,
            progression: progression,
            using: &randomNumberGenerator
        )
        return AbilityLoadout(basic: basic, skill: skill, ultimate: ultimate)
    }

    private static func pickAbility<RNG: RandomNumberGenerator>(
        from choices: [Ability],
        tier: AbilityTier,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG
    ) -> Ability? {
        guard progression.unlocks(tier), !choices.isEmpty else { return nil }
        return choices.randomElement(using: &randomNumberGenerator)
    }

    private static func pickDamageFirst<RNG: RandomNumberGenerator>(
        from choices: [Ability],
        tier: AbilityTier,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG
    ) -> Ability? {
        guard progression.unlocks(tier), !choices.isEmpty else { return nil }
        let damageChoices = choices.filter(dealsEnemyDamage)
        if let pick = damageChoices.randomElement(using: &randomNumberGenerator) {
            return pick
        }
        return choices.randomElement(using: &randomNumberGenerator)
    }

    private static func rebalanceLoadoutPair<RNG: RandomNumberGenerator>(
        hero: inout AbilityLoadout,
        pet: inout AbilityLoadout,
        heroCombatant: Combatant,
        petCombatant: Combatant,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG
    ) {
        for _ in 0 ..< 12 {
            if satisfiesDamageBudget(hero: hero, pet: pet, progression: progression) {
                return
            }

            let counts = damageCounts(hero: hero, pet: pet, progression: progression)
            if counts.damage < minimumDamageCount(for: progression) {
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
                continue
            }

            if counts.nonDamage > maxNonDamageAcrossPair {
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
        let tiers: [AbilityTier] = [.basic, .skill, .ultimate].filter { progression.unlocks($0) }
        let shuffledTiers = tiers.shuffled(using: &randomNumberGenerator)

        for tier in shuffledTiers {
            guard let current = loadout.ability(for: tier), !dealsEnemyDamage(current) else { continue }
            let choices = combatant.abilityChoices.abilities(for: tier).filter(dealsEnemyDamage)
            guard let replacement = choices.randomElement(using: &randomNumberGenerator) else { continue }
            loadout = loadout.selecting(replacement)
            return true
        }
        return false
    }

    static func satisfiesDamageBudget(
        hero: AbilityLoadout,
        pet: AbilityLoadout,
        progression: CombatantProgression
    ) -> Bool {
        let counts = damageCounts(hero: hero, pet: pet, progression: progression)
        guard counts.damage > 0 else { return false }
        guard counts.nonDamage <= maxNonDamageAcrossPair else { return false }
        return counts.damage >= minimumDamageCount(for: progression)
    }

    private static func minimumDamageCount(for progression: CombatantProgression) -> Int {
        unlockedSlotCount(for: progression) >= 4 ? 2 : 1
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
        let damage = abilities.filter(dealsEnemyDamage).count
        return (damage, abilities.count - damage)
    }

    private static func dealsEnemyDamage(_ ability: Ability) -> Bool {
        ability.directDamage > 0
    }
}
