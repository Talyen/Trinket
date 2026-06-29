import SwiftUI

struct StatusApplication: Hashable {
    let keyword: Keyword
    let durationTicks: Int
    let tickDamage: Int

    var summary: String {
        "\(keyword.rawValue) \(tickDamage) for \(durationTicks) ticks"
    }
}

struct ActiveStatus: Identifiable, Equatable, Hashable {
    let id: Int
    let keyword: Keyword
    var remainingTicks: Int
    let tickDamage: Int

    var summary: String {
        "\(remainingTicks) ticks remaining, \(tickDamage) damage each tick"
    }
}

struct StatusSummary: Identifiable, Equatable, Hashable {
    let keyword: Keyword
    let stackCount: Int
    let totalTickDamage: Int

    var id: Keyword { keyword }

    var text: String {
        "\(keyword.rawValue): \(totalTickDamage) damage next tick, \(stackCount) \(stackCount == 1 ? "stack" : "stacks")."
    }
}

struct Ability: Identifiable, Hashable {
    let id: String
    let name: String
    let tier: AbilityTier
    let directDamage: Int
    let damageKeyword: Keyword
    let statusApplication: StatusApplication?

    static let strike = Ability(
        id: "strike",
        name: "Strike",
        tier: .basic,
        directDamage: 1,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let shieldJab = Ability(
        id: "shield-jab",
        name: "Shield Jab",
        tier: .basic,
        directDamage: 1,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let quickCut = Ability(
        id: "quick-cut",
        name: "Quick Cut",
        tier: .basic,
        directDamage: 1,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let ember = Ability(
        id: "ember",
        name: "Ember",
        tier: .basic,
        directDamage: 1,
        damageKeyword: .physical,
        statusApplication: StatusApplication(keyword: .burn, durationTicks: 2, tickDamage: 1)
    )

    static let smite = Ability(
        id: "smite",
        name: "Smite",
        tier: .skill,
        directDamage: 3,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let guardingBlow = Ability(
        id: "guarding-blow",
        name: "Guarding Blow",
        tier: .skill,
        directDamage: 2,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let firebolt = Ability(
        id: "firebolt",
        name: "Firebolt",
        tier: .skill,
        directDamage: 3,
        damageKeyword: .physical,
        statusApplication: StatusApplication(keyword: .burn, durationTicks: 2, tickDamage: 1)
    )

    static let kindle = Ability(
        id: "kindle",
        name: "Kindle",
        tier: .skill,
        directDamage: 1,
        damageKeyword: .physical,
        statusApplication: StatusApplication(keyword: .burn, durationTicks: 3, tickDamage: 2)
    )

    static let radiantCrash = Ability(
        id: "radiant-crash",
        name: "Radiant Crash",
        tier: .ultimate,
        directDamage: 6,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let oathbreaker = Ability(
        id: "oathbreaker",
        name: "Oathbreaker",
        tier: .ultimate,
        directDamage: 5,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let meteor = Ability(
        id: "meteor",
        name: "Meteor",
        tier: .ultimate,
        directDamage: 6,
        damageKeyword: .physical,
        statusApplication: StatusApplication(keyword: .burn, durationTicks: 3, tickDamage: 2)
    )

    static let inferno = Ability(
        id: "inferno",
        name: "Inferno",
        tier: .ultimate,
        directDamage: 4,
        damageKeyword: .physical,
        statusApplication: StatusApplication(keyword: .burn, durationTicks: 3, tickDamage: 3)
    )

    var damage: Int {
        directDamage
    }

    var damageType: Keyword {
        damageKeyword
    }

    var keywords: [Keyword] {
        var result = [damageKeyword]
        if let statusApplication {
            result.append(statusApplication.keyword)
        }
        return result
    }

    var summary: String {
        if let statusApplication {
            return "\(directDamage) \(damageKeyword.rawValue) damage. Apply \(statusApplication.summary)."
        }

        return "\(directDamage) \(damageKeyword.rawValue) damage"
    }
}

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
        [basic, skill, ultimate].compactMap { $0 }
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
        selected: AbilityLoadout? = nil
    ) {
        self.basics = basics
        self.skills = skills
        self.ultimates = ultimates
        let defaultLoadout = AbilityLoadout(
            basic: basics.first,
            skill: skills.first,
            ultimate: ultimates.first
        )
        self.selected = AbilityChoices.resolvedLoadout(
            selected ?? defaultLoadout,
            basics: basics,
            skills: skills,
            ultimates: ultimates
        )
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

    private static func selectedAbility(_ ability: Ability?, in choices: [Ability]) -> Ability? {
        guard let ability else {
            return choices.first
        }

        return choices.first { $0.id == ability.id } ?? choices.first
    }
}
