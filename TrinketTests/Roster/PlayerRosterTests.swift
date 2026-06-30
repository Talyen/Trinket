import XCTest
@testable import Trinket

final class PlayerRosterTests: XCTestCase {
    // MARK: - Progression

    func testProgressionLevelsUpWhenXPCrossesThreshold() {
        let progression = CombatantProgression(level: 1, currentXP: 95, requiredXP: 100)
        let leveled = progression.addingExperience(10)

        XCTAssertEqual(leveled.level, 2)
        XCTAssertEqual(leveled.currentXP, 5)
        XCTAssertEqual(leveled.requiredXP, 150)
    }

    func testProgressionChainsMultipleLevelUps() {
        let progression = CombatantProgression(level: 1, currentXP: 95, requiredXP: 100)
        let leveled = progression.addingExperience(200)

        XCTAssertEqual(leveled.level, 3)
        XCTAssertEqual(leveled.currentXP, 45)
        XCTAssertEqual(leveled.requiredXP, 200)
    }

    func testProgressionIgnoresZeroOrNegativeXP() {
        let progression = CombatantProgression(level: 2, currentXP: 40, requiredXP: 120)

        XCTAssertEqual(progression.addingExperience(0), progression)
        XCTAssertEqual(progression.addingExperience(-10), progression)
    }

    func testProgressFractionClampedBetweenZeroAndOne() {
        let empty = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        let half = CombatantProgression(level: 1, currentXP: 50, requiredXP: 100)
        let full = CombatantProgression(level: 1, currentXP: 100, requiredXP: 100)
        let overCap = CombatantProgression(level: 1, currentXP: 150, requiredXP: 100)
        let zeroRequired = CombatantProgression(level: 1, currentXP: 10, requiredXP: 0)

        XCTAssertEqual(empty.progressFraction, 0, accuracy: 0.001)
        XCTAssertEqual(half.progressFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(full.progressFraction, 1, accuracy: 0.001)
        XCTAssertEqual(overCap.progressFraction, 1, accuracy: 0.001)
        XCTAssertEqual(zeroRequired.progressFraction, 0, accuracy: 0.001)
    }

    // MARK: - Loadouts

    func testSetLoadoutOverridesDefaultAbilityChoices() throws {
        var roster = PlayerRosterState.initial
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let customLoadout = AbilityLoadout(
            basic: .bash,
            skill: .smite,
            ultimate: .blessedAegis
        )

        roster.setLoadout(customLoadout, for: knight)
        let configured = roster.configuredCombatant(knight)

        XCTAssertEqual(configured.abilityLoadout.skill?.id, "smite")
        XCTAssertEqual(configured.abilityLoadout.ultimate?.id, "blessed-aegis")
    }

    func testInvalidLoadoutAbilityFallsBackToFirstChoice() {
        let choices = AbilityChoices(
            basics: [.bash, .shieldBash],
            skills: [.smite, .spikedShield],
            ultimates: [.blessedAegis, .crystalBulwark],
            selected: AbilityLoadout(
                basic: .bash,
                skill: Ability(id: "missing", name: "Missing", tier: .skill, directDamage: 0),
                ultimate: .blessedAegis
            )
        )

        XCTAssertEqual(choices.selected.skill?.id, "smite")
    }

    // MARK: - Active party

    func testSetActiveHeroAndPetUpdatesIDs() throws {
        var roster = PlayerRosterState.initial
        let wizard = try XCTUnwrap(GameContent.heroes.first { $0.id == "wizard" })
        let wolf = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })

        roster.setActiveHero(wizard)
        roster.setActivePet(wolf)

        XCTAssertEqual(roster.activeHeroID, "wizard")
        XCTAssertEqual(roster.activePetID, "wolf")
    }

    func testSetActiveHeroIgnoresLockedCombatantOnFreshStart() throws {
        var roster = PlayerRosterState.freshStart
        let wizard = try XCTUnwrap(GameContent.heroes.first { $0.id == "wizard" })

        roster.setActiveHero(wizard)

        XCTAssertEqual(roster.activeHeroID, PlayerRosterState.starterHeroID)
    }

    func testSetActivePetIgnoresLockedCombatantOnFreshStart() throws {
        var roster = PlayerRosterState.freshStart
        let wolf = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })

        roster.setActivePet(wolf)

        XCTAssertEqual(roster.activePetID, PlayerRosterState.starterPetID)
    }

    // MARK: - Gold

    func testGrantGoldIgnoresNonPositiveAmounts() {
        var roster = PlayerRosterState.initial
        roster.gold = 25

        roster.grantGold(0)
        roster.grantGold(-5)

        XCTAssertEqual(roster.gold, 25)
    }

    // MARK: - Equipment

    func testEquippedItemResolvesFromInventoryAndLoadout() throws {
        let roster = PlayerRosterState.initial
        let inventory = PlayerInventoryState.initial
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })

        let weapon = roster.equippedItem(for: .weapon, combatant: knight, inventory: inventory)

        XCTAssertEqual(weapon?.id, "longsword-basic")
        XCTAssertEqual(weapon?.baseType.slot, .weapon)
    }

    func testEquipmentLoadoutEquipAndUnequip() throws {
        let item = try XCTUnwrap(PlayerInventoryState.initial.item(matching: "wand-basic"))
        var loadout = EquipmentLoadout()

        loadout.equip(item)
        XCTAssertEqual(loadout.itemID(for: .weapon), "wand-basic")

        loadout.unequip(.weapon)
        XCTAssertNil(loadout.itemID(for: .weapon))
    }

    // MARK: - Inventory rewards

    func testAddRewardItemIgnoresDuplicateID() throws {
        let template = try XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic"))
        let stage = GameContent.chapters[0].stages[0]
        var inventory = PlayerInventoryState.freshStart
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)

        inventory.addRewardItem(from: template, for: stage, using: &randomNumberGenerator)
        inventory.addRewardItem(from: template, for: stage, using: &randomNumberGenerator)

        XCTAssertEqual(inventory.items.count, 1)
        XCTAssertEqual(inventory.items.first?.id, "chapter-1-stage-1-shortsword-basic")
    }
}
