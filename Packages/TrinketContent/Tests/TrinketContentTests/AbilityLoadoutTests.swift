import Testing
import TrinketContent
import TrinketCore

struct AbilityLoadoutTests {
    @Test func selectingReplacesAbilityInMatchingTier() throws {
        let loadout = AbilityLoadout(basic: .bash, skill: .smite, ultimate: .blessedAegis)

        let updated = loadout.selecting(.shieldBash)

        try #expect(updated.basic?.id == "shield-bash")
        try #expect(updated.skill?.id == "smite")
        try #expect(updated.ultimate?.id == "blessed-aegis")
    }

    @Test func abilityChoicesFallsBackWhenSelectedAbilityMissingFromPool() throws {
        let choices = AbilityChoices(
            basics: [.bash, .shieldBash],
            skills: [.smite, .spikedShield],
            ultimates: [.blessedAegis, .blizzard],
            selected: AbilityLoadout(
                basic: .bash,
                skill: Ability(id: "missing", name: "Missing", tier: .skill, directDamage: 0, description: "Missing"),
                ultimate: .blessedAegis
            )
        )

        try #expect(choices.selected.skill?.id == "smite")
    }
}
