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

    public static func loadout(
        for combatant: Combatant,
        selecting ability: Ability,
        progression: CombatantProgression
    ) -> AbilityLoadout {
        let base = defaultLoadout(for: combatant, progression: progression)
        return base.selecting(ability).unlocked(for: progression)
    }
}
