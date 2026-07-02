import Foundation

struct AbilityLoadout: Hashable {
    let basic: Ability?
    let skill: Ability?
    let ultimate: Ability?

    init(
        basic: Ability? = nil,
        skill: Ability? = nil,
        ultimate: Ability? = nil
    ) {
        self.basic = basic
        self.skill = skill
        self.ultimate = ultimate
    }

    var abilities: [Ability] {
        [basic, skill, ultimate].compactMap(\.self)
    }

    func ability(for tier: AbilityTier) -> Ability? {
        switch tier {
        case .basic:
            return basic
        case .skill:
            return skill
        case .ultimate:
            return ultimate
        }
    }

    func selecting(_ ability: Ability) -> AbilityLoadout {
        switch ability.tier {
        case .basic:
            return AbilityLoadout(basic: ability, skill: skill, ultimate: ultimate)
        case .skill:
            return AbilityLoadout(basic: basic, skill: ability, ultimate: ultimate)
        case .ultimate:
            return AbilityLoadout(basic: basic, skill: skill, ultimate: ability)
        }
    }

    func unlocked(for progression: CombatantProgression) -> AbilityLoadout {
        AbilityLoadout(
            basic: progression.unlocks(.basic) ? basic : nil,
            skill: progression.unlocks(.skill) ? skill : nil,
            ultimate: progression.unlocks(.ultimate) ? ultimate : nil
        )
    }
}

struct AbilityChoices: Hashable {
    let basics: [Ability]
    let skills: [Ability]
    let ultimates: [Ability]
    let selected: AbilityLoadout

    init(
        basics: [Ability],
        skills: [Ability],
        ultimates: [Ability],
        selected: AbilityLoadout? = nil,
        fillsMissingSelections: Bool = true
    ) {
        self.basics = basics
        self.skills = skills
        self.ultimates = ultimates
        let defaultLoadout = AbilityLoadout(
            basic: basics.first,
            skill: skills.first,
            ultimate: ultimates.first
        )
        let selectedLoadout = selected ?? defaultLoadout
        if fillsMissingSelections {
            self.selected = AbilityChoices.resolvedLoadout(
                selectedLoadout,
                basics: basics,
                skills: skills,
                ultimates: ultimates
            )
        } else {
            self.selected = AbilityChoices.resolvedLoadoutPreservingEmptyTiers(
                selectedLoadout,
                basics: basics,
                skills: skills,
                ultimates: ultimates
            )
        }
    }

    init(abilities: [Ability]) {
        self.init(
            basics: abilities.filter { $0.tier == .basic },
            skills: abilities.filter { $0.tier == .skill },
            ultimates: abilities.filter { $0.tier == .ultimate }
        )
    }

    func abilities(for tier: AbilityTier) -> [Ability] {
        switch tier {
        case .basic:
            return basics
        case .skill:
            return skills
        case .ultimate:
            return ultimates
        }
    }

    func withSelectedLoadout(_ loadout: AbilityLoadout) -> AbilityChoices {
        AbilityChoices(
            basics: basics,
            skills: skills,
            ultimates: ultimates,
            selected: loadout
        )
    }

    func withSelectedLoadoutPreservingEmptyTiers(_ loadout: AbilityLoadout) -> AbilityChoices {
        AbilityChoices(
            basics: basics,
            skills: skills,
            ultimates: ultimates,
            selected: loadout,
            fillsMissingSelections: false
        )
    }

    private static func resolvedLoadout(
        _ loadout: AbilityLoadout,
        basics: [Ability],
        skills: [Ability],
        ultimates: [Ability]
    ) -> AbilityLoadout {
        AbilityLoadout(
            basic: selectedAbility(loadout.basic, in: basics),
            skill: selectedAbility(loadout.skill, in: skills),
            ultimate: selectedAbility(loadout.ultimate, in: ultimates)
        )
    }

    private static func resolvedLoadoutPreservingEmptyTiers(
        _ loadout: AbilityLoadout,
        basics: [Ability],
        skills: [Ability],
        ultimates: [Ability]
    ) -> AbilityLoadout {
        AbilityLoadout(
            basic: selectedAbilityIfPresent(loadout.basic, in: basics),
            skill: selectedAbilityIfPresent(loadout.skill, in: skills),
            ultimate: selectedAbilityIfPresent(loadout.ultimate, in: ultimates)
        )
    }

    private static func selectedAbility(_ ability: Ability?, in choices: [Ability]) -> Ability? {
        guard let ability else {
            return choices.first
        }

        return choices.first { $0.id == ability.id } ?? choices.first
    }

    private static func selectedAbilityIfPresent(_ ability: Ability?, in choices: [Ability]) -> Ability? {
        guard let ability else { return nil }
        return choices.first { $0.id == ability.id } ?? choices.first
    }
}
