import Testing
import TrinketContent
import TrinketCore

/// Ability loadout selection and tier-unlock filtering.
struct AbilityLoadoutTests {
    @Test func selectingReplacesAbilityInMatchingTier() throws {
        let loadout = AbilityLoadout(basic: .bash, skill: .smite, ultimate: .blessedAegis)

        let updated = loadout.selecting(.shieldBash)

        try #expect(updated.basic?.id == "shield-bash")
        try #expect(updated.skill?.id == "smite")
        try #expect(updated.ultimate?.id == "blessed-aegis")
    }

    @Test func unlockedFiltersTiersByProgressionLevel() throws {
        let loadout = AbilityLoadout(basic: .block, skill: .sunder, ultimate: .blessedAegis)
        let levelOne = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)

        let unlocked = loadout.unlocked(for: levelOne)

        try #expect(unlocked.basic?.id == "block")
        try #expect(unlocked.skill?.id == "sunder")
        try #expect(unlocked.ultimate == nil)
    }

    @Test func unlockedRestoresUltimateAtLevelSix() throws {
        let loadout = AbilityLoadout(basic: .block, skill: .sunder, ultimate: .blessedAegis)
        let levelSix = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)

        let unlocked = loadout.unlocked(for: levelSix)

        try #expect(unlocked.abilities.map(\.id) == ["block", "sunder", "blessed-aegis"])
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
