import Foundation
import TrinketCore

public struct AbilityLoadout: Hashable, Sendable {
    public let basic: Ability?
    public let skill: Ability?
    public let ultimate: Ability?

    public init(
        basic: Ability? = nil,
        skill: Ability? = nil,
        ultimate: Ability? = nil
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
        self.selected = Self.resolvedLoadout(
            selectedLoadout,
            basics: basics,
            skills: skills,
            ultimates: ultimates,
            fillsMissingSelections: fillsMissingSelections
        )
    }

    public init(abilities: [Ability]) {
        self.init(
            basics: abilities.filter { $0.tier == .basic },
            skills: abilities.filter { $0.tier == .skill },
            ultimates: abilities.filter { $0.tier == .ultimate }
        )
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

    public func withSelectedLoadout(_ loadout: AbilityLoadout) -> Self {
        Self(
            basics: basics,
            skills: skills,
            ultimates: ultimates,
            selected: loadout
        )
    }

    public func withSelectedLoadoutPreservingEmptyTiers(_ loadout: AbilityLoadout) -> Self {
        Self(
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
        ultimates: [Ability],
        fillsMissingSelections: Bool
    ) -> AbilityLoadout {
        AbilityLoadout(
            basic: selectedAbility(loadout.basic, in: basics, fillIfMissing: fillsMissingSelections),
            skill: selectedAbility(loadout.skill, in: skills, fillIfMissing: fillsMissingSelections),
            ultimate: selectedAbility(loadout.ultimate, in: ultimates, fillIfMissing: fillsMissingSelections)
        )
    }

    private static func selectedAbility(
        _ ability: Ability?,
        in choices: [Ability],
        fillIfMissing: Bool
    ) -> Ability? {
        guard let ability else {
            return fillIfMissing ? choices.first : nil
        }
        return choices.first { $0.id == ability.id } ?? choices.first
    }
}
