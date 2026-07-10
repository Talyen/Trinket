import Testing
import TrinketCore
import TrinketContent

/// Ability loadout selection and tier-unlock filtering.
@Suite
struct AbilityLoadoutTests {
    @Test func selectingReplacesAbilityInMatchingTier() throws {
        let loadout = AbilityLoadout(basic: .bash, skill: .smite, ultimate: .blessedAegis)

        let updated = loadout.selecting(.shieldBash)

        try #expect(updated.basic?.id == "shield-bash")
        try #expect(updated.skill?.id == "smite")
        try #expect(updated.ultimate?.id == "blessed-aegis")
    }

    @Test func unlockedFiltersTiersByProgressionLevel() throws {
        let loadout = AbilityLoadout(basic: .block, skill: .plateMail, ultimate: .sanctifiedPlate)
        let levelOne = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)

        let unlocked = loadout.unlocked(for: levelOne)

        try #expect(unlocked.basic?.id == "block")
        try #expect(unlocked.skill?.id == "plate-mail")
        try #expect(unlocked.ultimate == nil)
    }

    @Test func unlockedRestoresUltimateAtLevelSix() throws {
        let loadout = AbilityLoadout(basic: .block, skill: .plateMail, ultimate: .sanctifiedPlate)
        let levelSix = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)

        let unlocked = loadout.unlocked(for: levelSix)

        try #expect(unlocked.abilities.map(\.id) == ["block", "plate-mail", "sanctified-plate"])
    }

    @Test func abilityChoicesFallsBackWhenSelectedAbilityMissingFromPool() throws {
        let choices = AbilityChoices(
            basics: [.bash, .shieldBash],
            skills: [.smite, .spikedShield],
            ultimates: [.blessedAegis, .crystalBulwark],
            selected: AbilityLoadout(
                basic: .bash,
                skill: Ability(id: "missing", name: "Missing", tier: .skill, directDamage: 0, description: "Missing"),
                ultimate: .blessedAegis
            )
        )

        try #expect(choices.selected.skill?.id == "smite")
    }
}
