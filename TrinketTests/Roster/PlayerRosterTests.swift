import XCTest
@testable import Trinket

final class PlayerRosterTests: XCTestCase {
    // MARK: - Loadouts

    func testAbilityTierUnlockLevels() {
        XCTAssertEqual(AbilityTier.basic.unlockLevel, 1)
        XCTAssertEqual(AbilityTier.skill.unlockLevel, 3)
        XCTAssertEqual(AbilityTier.ultimate.unlockLevel, 6)
    }

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

    func testBattleConfiguredCombatantFiltersLockedPlayerAbilityTiers() throws {
        var roster = PlayerRosterState.freshStart
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let customLoadout = AbilityLoadout(
            basic: .shieldBash,
            skill: .spikedShield,
            ultimate: .plateMail
        )

        roster.setLoadout(customLoadout, for: knight)
        let configured = roster.battleConfiguredCombatant(knight)

        XCTAssertEqual(roster.loadout(for: knight).skill?.id, "spiked-shield")
        XCTAssertEqual(configured.abilityLoadout.basic?.id, "shield-bash")
        XCTAssertNil(configured.abilityLoadout.skill)
        XCTAssertNil(configured.abilityLoadout.ultimate)
        XCTAssertEqual(configured.abilities.map(\.id), ["shield-bash"])
    }

    func testBattleConfiguredCombatantRestoresPlayerAbilityTiersAtUnlockLevels() throws {
        var roster = PlayerRosterState.freshStart
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let customLoadout = AbilityLoadout(
            basic: .shieldBash,
            skill: .spikedShield,
            ultimate: .plateMail
        )
        roster.setLoadout(customLoadout, for: knight)

        roster.progressions[knight.id] = CombatantProgression(level: 3, currentXP: 0, requiredXP: 200)
        XCTAssertEqual(roster.battleConfiguredCombatant(knight).abilities.map(\.id), ["shield-bash", "spiked-shield"])

        roster.progressions[knight.id] = CombatantProgression(level: 6, currentXP: 0, requiredXP: 350)
        XCTAssertEqual(
            roster.battleConfiguredCombatant(knight).abilities.map(\.id),
            ["shield-bash", "spiked-shield", "plate-mail"]
        )
    }

    func testBattleConfiguredCombatantDoesNotFilterEnemyAbilities() throws {
        let roster = PlayerRosterState.freshStart
        let enemy = try XCTUnwrap(GameContent.enemies.first?.combatant)
        let configured = roster.battleConfiguredCombatant(enemy)

        XCTAssertEqual(configured.abilityLoadout.skill?.tier, .skill)
        XCTAssertEqual(configured.abilityLoadout.ultimate?.tier, .ultimate)
    }

    func testInvalidLoadoutAbilityFallsBackToFirstChoice() {
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

    func testSetEquipmentLoadoutUnequipsItemFromOtherCombatants() throws {
        var roster = PlayerRosterState.initial
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let wizard = try XCTUnwrap(GameContent.heroes.first { $0.id == "wizard" })
        let wand = try XCTUnwrap(PlayerInventoryState.initial.item(matching: "wand-basic"))

        var wizardLoadout = roster.equipmentLoadout(for: wizard)
        wizardLoadout.equip(wand)
        roster.setEquipmentLoadout(wizardLoadout, for: wizard)

        var knightLoadout = roster.equipmentLoadout(for: knight)
        knightLoadout.equip(wand)
        roster.setEquipmentLoadout(knightLoadout, for: knight)

        XCTAssertEqual(roster.equipmentLoadout(for: knight).itemID(for: .weapon), wand.id)
        XCTAssertNil(roster.equipmentLoadout(for: wizard).itemID(for: .weapon))
    }

    func testInventorySlotUnlocksWhenSlotItemExists() throws {
        let weapon = try XCTUnwrap(PlayerInventoryState.initial.item(matching: "wand-basic"))
        var inventory = PlayerInventoryState.freshStart

        XCTAssertFalse(inventory.hasItem(for: .weapon))
        XCTAssertFalse(inventory.hasItem(for: .armor))

        inventory.items.append(weapon)

        XCTAssertTrue(inventory.hasItem(for: .weapon))
        XCTAssertFalse(inventory.hasItem(for: .armor))
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
