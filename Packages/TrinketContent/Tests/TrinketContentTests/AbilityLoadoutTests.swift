import XCTest
import TrinketContent

/// Ability loadout selection and tier-unlock filtering.
final class AbilityLoadoutTests: XCTestCase {
    func testSelectingReplacesAbilityInMatchingTier() {
        let loadout = AbilityLoadout(basic: .bash, skill: .smite, ultimate: .blessedAegis)

        let updated = loadout.selecting(.shieldBash)

        XCTAssertEqual(updated.basic?.id, "shield-bash")
        XCTAssertEqual(updated.skill?.id, "smite")
        XCTAssertEqual(updated.ultimate?.id, "blessed-aegis")
    }

    func testUnlockedFiltersTiersByProgressionLevel() {
        let loadout = AbilityLoadout(basic: .shieldBash, skill: .spikedShield, ultimate: .plateMail)
        let levelOne = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)

        let unlocked = loadout.unlocked(for: levelOne)

        XCTAssertEqual(unlocked.basic?.id, "shield-bash")
        XCTAssertNil(unlocked.skill)
        XCTAssertNil(unlocked.ultimate)
    }

    func testUnlockedRestoresUltimateAtLevelSix() {
        let loadout = AbilityLoadout(basic: .shieldBash, skill: .spikedShield, ultimate: .plateMail)
        let levelSix = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)

        let unlocked = loadout.unlocked(for: levelSix)

        XCTAssertEqual(unlocked.abilities.map(\.id), ["shield-bash", "spiked-shield", "plate-mail"])
    }

    func testAbilityChoicesFallsBackWhenSelectedAbilityMissingFromPool() {
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

        XCTAssertEqual(choices.selected.skill?.id, "smite")
    }
}
