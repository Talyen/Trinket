import XCTest
import TrinketContent
import TrinketCore
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

    func testSanitizeJourneyClampsInvalidStageAndChapterIDs() {
        var journey = JourneyProgressState.initial
        journey.activeChapterID = "missing-chapter"
        journey.activeStageID = "missing-stage"
        journey.completedStageIDs = ["chapter-1-stage-1", "missing-stage"]
        journey.claimedRewardStageIDs = ["missing-reward"]

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        XCTAssertEqual(sanitized.activeChapterID, "chapter-1")
        XCTAssertEqual(sanitized.activeStageID, "chapter-1-stage-2")
        XCTAssertEqual(sanitized.completedStageIDs, ["chapter-1-stage-1"])
        XCTAssertTrue(sanitized.claimedRewardStageIDs.isEmpty)
    }

    func testSanitizeJourneyAlignsActiveChapterWithActiveStage() {
        var journey = JourneyProgressState.initial
        journey.activeChapterID = "chapter-2"
        journey.activeStageID = "chapter-1-stage-2"
        journey.completedStageIDs = ["chapter-1-stage-1"]

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        XCTAssertEqual(sanitized.activeStageID, "chapter-1-stage-2")
        XCTAssertEqual(sanitized.activeChapterID, "chapter-1")
    }

    func testSanitizeJourneyMarksClaimedStagesAsCompleted() {
        var journey = JourneyProgressState.initial
        journey.claimedRewardStageIDs.insert("chapter-1-stage-1")

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        XCTAssertTrue(sanitized.completedStageIDs.contains("chapter-1-stage-1"))
        XCTAssertTrue(sanitized.claimedRewardStageIDs.contains("chapter-1-stage-1"))
    }

    func testSanitizeRosterFiltersInvalidUnlockIDs() {
        let roster = PlayerRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activePetID: PlayerRosterState.starterPetID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID, "missing-hero"],
            unlockedPetIDs: [PlayerRosterState.starterPetID, "missing-pet"],
            abilityLoadouts: [:],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventory: .freshStart)

        XCTAssertEqual(sanitized.unlockedHeroIDs, [PlayerRosterState.starterHeroID])
        XCTAssertEqual(sanitized.unlockedPetIDs, [PlayerRosterState.starterPetID])
    }

    func testSanitizeRosterFallsBackToStartersWhenUnlocksEmpty() {
        let roster = PlayerRosterState(
            activeHeroID: "wizard",
            activePetID: "wolf",
            unlockedHeroIDs: ["missing-hero"],
            unlockedPetIDs: ["missing-pet"],
            abilityLoadouts: [:],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventory: .freshStart)

        XCTAssertEqual(sanitized.unlockedHeroIDs, [PlayerRosterState.starterHeroID])
        XCTAssertEqual(sanitized.unlockedPetIDs, [PlayerRosterState.starterPetID])
        XCTAssertEqual(sanitized.activeHeroID, PlayerRosterState.starterHeroID)
        XCTAssertEqual(sanitized.activePetID, PlayerRosterState.starterPetID)
    }

    func testSanitizeRosterStripsUnknownCombatantAbilityLoadouts() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        var unknownLoadout = knight.abilityLoadout
        unknownLoadout.skill = knight.abilityChoices.abilities(for: .skill).first
        let roster = PlayerRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activePetID: PlayerRosterState.starterPetID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID],
            unlockedPetIDs: [PlayerRosterState.starterPetID],
            abilityLoadouts: [
                "knight": knight.abilityLoadout,
                "missing-combatant": unknownLoadout
            ],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventory: .freshStart)

        XCTAssertEqual(Set(sanitized.abilityLoadouts.keys), ["knight"])
    }

    func testSanitizeRosterResolvesInvalidAbilityIDs() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        var invalidLoadout = knight.abilityLoadout
        invalidLoadout.skill = Ability(
            id: "missing-ability",
            name: "Missing",
            tier: .skill,
            description: "Missing"
        )
        let roster = PlayerRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activePetID: PlayerRosterState.starterPetID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID],
            unlockedPetIDs: [PlayerRosterState.starterPetID],
            abilityLoadouts: ["knight": invalidLoadout],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventory: .freshStart)

        XCTAssertEqual(
            sanitized.loadout(for: knight).skill?.id,
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
        let roster = PlayerRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activePetID: PlayerRosterState.starterPetID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID],
            unlockedPetIDs: [PlayerRosterState.starterPetID],
            abilityLoadouts: [:],
            progressions: [:],
            equipmentLoadouts: [
                "knight": EquipmentLoadout(itemIDsBySlot: [.weapon: "missing-item"])
            ],
            gold: 0
        )
        var save = PlayerSave.fresh
        save.inventory = PlayerInventoryState(items: [weapon])
        save.roster = roster

        let sanitized = PlayerSaveSanitizer.sanitize(save)

        XCTAssertNil(sanitized.roster.equipmentLoadout(for: knight).itemID(for: .weapon))
        XCTAssertEqual(sanitized.inventory.items.map(\.id), ["weapon-id"])
    }

    func testSanitizeRosterStripsWeaponSlotFromPets() throws {
        let bear = try XCTUnwrap(GameContent.pets.first { $0.id == "bear" })
        let weaponBase = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.slot == .weapon })
        let trinketBase = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.slot == .trinket })
        let weapon = InventoryItem(
            id: "weapon-id",
            templateID: "weapon-template",
            baseType: weaponBase,
            rarity: .basic,
            displayName: "Test Sword",
            affixes: []
        )
        let trinket = InventoryItem(
            id: "trinket-id",
            templateID: "trinket-template",
            baseType: trinketBase,
            rarity: .basic,
            displayName: "Test Ring",
            affixes: []
        )
        let roster = PlayerRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activePetID: PlayerRosterState.starterPetID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID],
            unlockedPetIDs: [PlayerRosterState.starterPetID],
            abilityLoadouts: [:],
            progressions: [:],
            equipmentLoadouts: [
                "bear": EquipmentLoadout(itemIDsBySlot: [
                    .weapon: weapon.id,
                    .trinket: trinket.id
                ])
            ],
            gold: 0
        )
        var save = PlayerSave.fresh
        save.inventory = PlayerInventoryState(items: [weapon, trinket])
        save.roster = roster

        let sanitized = PlayerSaveSanitizer.sanitize(save)
        let loadout = sanitized.roster.equipmentLoadout(for: bear)

        XCTAssertNil(loadout.itemID(for: .weapon))
        XCTAssertEqual(loadout.itemID(for: .trinket), trinket.id)
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
        save.inventory = PlayerInventoryState(items: [item, item])
        save.roster.unlockedHeroIDs = [PlayerRosterState.starterHeroID, "invalid-hero"]

        let sanitized = PlayerSaveSanitizer.sanitize(save)

        XCTAssertEqual(sanitized.inventory.items.map(\.id), ["item-id"])
        XCTAssertEqual(sanitized.roster.unlockedHeroIDs, [PlayerRosterState.starterHeroID])
    }
}
