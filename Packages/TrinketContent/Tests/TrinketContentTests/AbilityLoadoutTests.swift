import Testing
import TrinketCore
import TrinketContent

/// Ability loadout selection and tier-unlock filtering.
@Suite
struct AbilityLoadoutTests {
    @Test func selectingReplacesAbilityInMatchingTier() {
        let loadout = AbilityLoadout(basic: .bash, skill: .smite, ultimate: .blessedAegis)

        let updated = loadout.selecting(.shieldBash)

        #expect(updated.basic?.id == "shield-bash")
        #expect(updated.skill?.id == "smite")
        #expect(updated.ultimate?.id == "blessed-aegis")
    }

    @Test func unlockedFiltersTiersByProgressionLevel() {
        let loadout = AbilityLoadout(basic: .shieldBash, skill: .spikedShield, ultimate: .plateMail)
        let levelOne = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)

        let unlocked = loadout.unlocked(for: levelOne)

        #expect(unlocked.basic?.id == "shield-bash")
        #expect(unlocked.skill?.id == "spiked-shield")
        #expect(unlocked.ultimate == nil)
    }

    @Test func unlockedRestoresUltimateAtLevelSix() {
        let loadout = AbilityLoadout(basic: .shieldBash, skill: .spikedShield, ultimate: .plateMail)
        let levelSix = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)

        let unlocked = loadout.unlocked(for: levelSix)

        #expect(unlocked.abilities.map(\.id) == ["shield-bash", "spiked-shield", "plate-mail"])
    }

    @Test func abilityChoicesFallsBackWhenSelectedAbilityMissingFromPool() {
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

        #expect(choices.selected.skill?.id == "smite")
    }
}
