import Foundation
import TrinketCore

public struct AbilityLoadout: Hashable, Sendable {
    public let basic: Ability?
    public let skill: Ability?
    public let ultimate: Ability?

    public init(
        basic: Ability? = nil,
        skill: Ability? = nil,
        ultimate: Ability? = nil,
    ) {
        self.basic = basic
        self.skill = skill
        self.ultimate = ultimate
    }

    public var abilities: [Ability] {
        [basic, skill, ultimate].compactMap(\.self)
    }

    public func ability(for tier: AbilityTier) -> Ability? {
        switch tier {
        case .basic:
            basic
        case .skill:
            skill
        case .ultimate:
            ultimate
        }
    }

    public func selecting(_ ability: Ability) -> Self {
        switch ability.tier {
        case .basic:
            Self(basic: ability, skill: skill, ultimate: ultimate)
        case .skill:
            Self(basic: basic, skill: ability, ultimate: ultimate)
        case .ultimate:
            Self(basic: basic, skill: skill, ultimate: ability)
        }
    }
}

public struct AbilityChoices: Hashable, Sendable {
    public let basics: [Ability]
    public let skills: [Ability]
    public let ultimates: [Ability]
    public let selected: AbilityLoadout

    public init(
        basics: [Ability],
        skills: [Ability],
        ultimates: [Ability],
        selected: AbilityLoadout? = nil,
        fillsMissingSelections: Bool = true,
    ) {
        self.basics = basics
        self.skills = skills
        self.ultimates = ultimates
        // An omitted loadout selects defaults even when explicit empty tiers are preserved.
        let fillIfMissing = selected == nil || fillsMissingSelections
        self.selected = AbilityLoadout(
            basic: Self.selectedAbility(selected?.basic, in: basics, fillIfMissing: fillIfMissing),
            skill: Self.selectedAbility(selected?.skill, in: skills, fillIfMissing: fillIfMissing),
            ultimate: Self.selectedAbility(selected?.ultimate, in: ultimates, fillIfMissing: fillIfMissing),
        )
    }

    public init(abilities: [Ability]) {
        var basics: [Ability] = []
        var skills: [Ability] = []
        var ultimates: [Ability] = []
        for ability in abilities {
            switch ability.tier {
            case .basic: basics.append(ability)
            case .skill: skills.append(ability)
            case .ultimate: ultimates.append(ability)
            }
        }
        self.init(basics: basics, skills: skills, ultimates: ultimates)
    }

    public func abilities(for tier: AbilityTier) -> [Ability] {
        switch tier {
        case .basic:
            basics
        case .skill:
            skills
        case .ultimate:
            ultimates
        }
    }

    public func withSelectedLoadout(
        _ loadout: AbilityLoadout,
        fillsMissingSelections: Bool = true,
    ) -> Self {
        Self(
            basics: basics,
            skills: skills,
            ultimates: ultimates,
            selected: loadout,
            fillsMissingSelections: fillsMissingSelections,
        )
    }

    private static func selectedAbility(
        _ ability: Ability?,
        in choices: [Ability],
        fillIfMissing: Bool,
    ) -> Ability? {
        guard let ability else {
            return fillIfMissing ? choices.first : nil
        }
        return choices.first { $0.id == ability.id } ?? choices.first
    }
}
