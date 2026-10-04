import Testing
import TrinketContent
import TrinketCore

struct AbilityLoadoutTests {
    @Test func `selecting replaces ability in matching tier`() throws {
        let loadout = AbilityLoadout(basic: .bash, skill: .smite, ultimate: .blessedAegis)

        let updated = loadout.selecting(.shieldBash)

        try #expect(updated.basic?.id == "shield-bash")
        try #expect(updated.skill?.id == "smite")
        try #expect(updated.ultimate?.id == "blessed-aegis")
    }

    @Test func `ability choices falls back when selected ability missing from pool`() {
        let choices = AbilityChoices(
            basics: [.bash, .shieldBash],
            skills: [.smite, .spikedShield],
            ultimates: [.blessedAegis, .blizzard],
            selected: AbilityLoadout(
                basic: .bash,
                skill: Ability(id: "missing", name: "Missing", tier: .skill, directDamage: 0, description: "Missing"),
                ultimate: .blessedAegis,
            ),
        )

        #expect(choices.selected == AbilityLoadout(basic: .bash, skill: .smite, ultimate: .blessedAegis))
    }

    @Test func `choices keep tier order and replace stale selected definitions`() {
        let stale = Ability(id: Ability.smite.id, name: "Old Smite", tier: .skill, directDamage: 99)
        let choices = AbilityChoices(abilities: [.smite, .bash, .blessedAegis, .shieldBash, .spikedShield])
            .withSelectedLoadout(AbilityLoadout(basic: .shieldBash, skill: stale, ultimate: .blessedAegis))
        #expect(choices.basics == [.bash, .shieldBash])
        #expect(choices.skills == [.smite, .spikedShield])
        #expect(choices.selected == AbilityLoadout(basic: .shieldBash, skill: .smite, ultimate: .blessedAegis))
    }

    @Test func `explicit empty tiers survive while omitted loadouts get defaults`() {
        let choices = AbilityChoices(basics: [.bash], skills: [.smite], ultimates: [.blessedAegis], fillsMissingSelections: false)
        #expect(choices.selected == AbilityLoadout(basic: .bash, skill: .smite, ultimate: .blessedAegis))
        let empty = choices.withSelectedLoadout(AbilityLoadout(basic: .bash), fillsMissingSelections: false)
        #expect(empty.selected == AbilityLoadout(basic: .bash))
        #expect(empty.withSelectedLoadout(empty.selected).selected == choices.selected)
    }
}
