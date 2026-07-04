import Foundation
import TrinketCore
import TrinketContent

public enum AbilityLoadoutSampler {
    public static func defaultLoadout(
        for combatant: Combatant,
        progression: CombatantProgression
    ) -> AbilityLoadout {
        combatant
            .withAbilityLoadout(combatant.abilityLoadout)
            .abilityLoadout
            .unlocked(for: progression)
    }

    public static func randomLoadout<RNG: RandomNumberGenerator>(
        for combatant: Combatant,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG
    ) -> AbilityLoadout {
        let choices = combatant.abilityChoices
        let basic = progression.unlocks(.basic)
            ? choices.basics.randomElement(using: &randomNumberGenerator)
            : nil
        let skill = progression.unlocks(.skill)
            ? choices.skills.randomElement(using: &randomNumberGenerator)
            : nil
        let ultimate = progression.unlocks(.ultimate)
            ? choices.ultimates.randomElement(using: &randomNumberGenerator)
            : nil
        return AbilityLoadout(basic: basic, skill: skill, ultimate: ultimate)
    }

    public static func randomLoadoutPair<RNG: RandomNumberGenerator>(
        hero: Combatant,
        pet: Combatant,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG
    ) -> (AbilityLoadout, AbilityLoadout) {
        for _ in 0 ..< 12 {
            let heroLoadout = randomLoadout(for: hero, progression: progression, using: &randomNumberGenerator)
            let petLoadout = randomLoadout(for: pet, progression: progression, using: &randomNumberGenerator)
            if hasEnemyDamage(in: heroLoadout) || hasEnemyDamage(in: petLoadout) {
                return (heroLoadout, petLoadout)
            }
        }

        return (
            damageBiasedLoadout(for: hero, progression: progression, using: &randomNumberGenerator),
            damageBiasedLoadout(for: pet, progression: progression, using: &randomNumberGenerator)
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

    private static func damageBiasedLoadout<RNG: RandomNumberGenerator>(
        for combatant: Combatant,
        progression: CombatantProgression,
        using randomNumberGenerator: inout RNG
    ) -> AbilityLoadout {
        let choices = combatant.abilityChoices
        let basic = progression.unlocks(.basic)
            ? choices.basics.first(where: dealsEnemyDamage) ?? choices.basics.first
            : nil
        let skill = progression.unlocks(.skill)
            ? choices.skills.first(where: dealsEnemyDamage) ?? choices.skills.first
            : nil
        let ultimate = progression.unlocks(.ultimate)
            ? choices.ultimates.randomElement(using: &randomNumberGenerator)
            : nil
        return AbilityLoadout(basic: basic, skill: skill, ultimate: ultimate)
    }

    private static func hasEnemyDamage(in loadout: AbilityLoadout) -> Bool {
        loadout.abilities.contains(where: dealsEnemyDamage)
    }

    private static func dealsEnemyDamage(_ ability: Ability) -> Bool {
        ability.directDamage > 0
    }
}
