import XCTest
import BattleEngine
import TrinketContent
@testable import TrinketPersistence

@MainActor
final class PlayerSaveSanitizerTests: XCTestCase {
    func testSanitizeInventoryRemovesDuplicateItemIDs() throws {
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first)
        let duplicate = InventoryItem(
            id: "shared-id",
            templateID: "template-a",
            baseType: baseType,
            rarity: .basic,
            displayName: "First",
            affixes: []
        )
        let unique = InventoryItem(
            id: "unique-id",
            templateID: "template-b",
            baseType: baseType,
            rarity: .basic,
            displayName: "Second",
            affixes: []
        )
        let inventory = PlayerInventoryState(items: [duplicate, duplicate, unique])

        let sanitized = PlayerSaveSanitizer.sanitizeInventory(inventory)

        XCTAssertEqual(sanitized.items.map(\.id), ["shared-id", "unique-id"])
    }

    func testSanitizeRosterFiltersInvalidUnlockIDs() {
        let roster = SavedRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activePetID: PlayerRosterState.starterPetID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID, "missing-hero"],
            unlockedPetIDs: [PlayerRosterState.starterPetID, "missing-pet"],
            abilityLoadouts: [:],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventoryItemIDs: [])
        let playerRoster = sanitized.roster(inventoryItemIDs: [])

        XCTAssertEqual(playerRoster.unlockedHeroIDs, [PlayerRosterState.starterHeroID])
        XCTAssertEqual(playerRoster.unlockedPetIDs, [PlayerRosterState.starterPetID])
    }

    func testSanitizeRosterFallsBackToStartersWhenUnlocksEmpty() {
        let roster = SavedRosterState(
            activeHeroID: "wizard",
            activePetID: "wolf",
            unlockedHeroIDs: ["missing-hero"],
            unlockedPetIDs: ["missing-pet"],
            abilityLoadouts: [:],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventoryItemIDs: [])
        let playerRoster = sanitized.roster(inventoryItemIDs: [])

        XCTAssertEqual(playerRoster.unlockedHeroIDs, [PlayerRosterState.starterHeroID])
        XCTAssertEqual(playerRoster.unlockedPetIDs, [PlayerRosterState.starterPetID])
        XCTAssertEqual(playerRoster.activeHeroID, PlayerRosterState.starterHeroID)
        XCTAssertEqual(playerRoster.activePetID, PlayerRosterState.starterPetID)
    }

    func testSanitizeRosterStripsUnknownCombatantAbilityLoadouts() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        var unknownLoadout = SavedAbilityLoadout(knight.abilityLoadout)
        unknownLoadout.basicID = "smite"
        let roster = SavedRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activePetID: PlayerRosterState.starterPetID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID],
            unlockedPetIDs: [PlayerRosterState.starterPetID],
            abilityLoadouts: [
                "knight": SavedAbilityLoadout(knight.abilityLoadout),
                "missing-combatant": unknownLoadout
            ],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventoryItemIDs: [])

        XCTAssertEqual(Set(sanitized.abilityLoadouts.keys), ["knight"])
    }

    func testSanitizeRosterResolvesInvalidAbilityIDs() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        var savedLoadout = SavedAbilityLoadout(knight.abilityLoadout)
        savedLoadout.skillID = "missing-ability"
        let roster = SavedRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activePetID: PlayerRosterState.starterPetID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID],
            unlockedPetIDs: [PlayerRosterState.starterPetID],
            abilityLoadouts: ["knight": savedLoadout],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventoryItemIDs: [])
        let playerRoster = sanitized.roster(inventoryItemIDs: [])

        XCTAssertEqual(
            playerRoster.loadout(for: knight).skill?.id,
            knight.abilityLoadout.skill?.id
        )
    }

    func testSanitizeRosterPrunesMissingEquipmentItems() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.slot == .weapon })
        let weapon = InventoryItem(
            id: "weapon-id",
            templateID: "weapon-template",
            baseType: baseType,
            rarity: .basic,
            displayName: "Test Sword",
            affixes: []
        )
        let roster = SavedRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activePetID: PlayerRosterState.starterPetID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID],
            unlockedPetIDs: [PlayerRosterState.starterPetID],
            abilityLoadouts: [:],
            progressions: [:],
            equipmentLoadouts: [
                "knight": SavedEquipmentLoadout(
                    EquipmentLoadout(itemIDsBySlot: [.weapon: "missing-item"])
                )
            ],
            gold: 0
        )
        var save = PlayerSave.fresh
        save.inventory = SavedInventoryState(PlayerInventoryState(items: [weapon]))
        save.roster = roster

        let sanitized = PlayerSaveSanitizer.sanitize(save)
        let playerRoster = sanitized.playerRoster(
            inventoryItemIDs: Set(sanitized.inventory.items.map(\.id))
        )

        XCTAssertNil(playerRoster.equipmentLoadout(for: knight).itemID(for: .weapon))
        XCTAssertEqual(sanitized.inventory.items.map(\.id), ["weapon-id"])
    }

    func testSanitizeFullPipelineCombinesInventoryAndRoster() throws {
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first)
        let item = InventoryItem(
            id: "item-id",
            templateID: "template",
            baseType: baseType,
            rarity: .basic,
            displayName: "Duplicate",
            affixes: []
        )
        var save = PlayerSave.fresh
        save.inventory = SavedInventoryState(PlayerInventoryState(items: [item, item]))
        save.roster.unlockedHeroIDs = [PlayerRosterState.starterHeroID, "invalid-hero"]

        let sanitized = PlayerSaveSanitizer.sanitize(save)

        XCTAssertEqual(sanitized.inventory.items.map(\.id), ["item-id"])
        XCTAssertEqual(sanitized.roster.unlockedHeroIDs, [PlayerRosterState.starterHeroID])
    }
}
