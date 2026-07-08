import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

@Suite @MainActor
final class PlayerSaveSanitizerTests {
    @Test func sanitizeInventoryRemovesDuplicateItemIDs() throws {
        let baseType = try #require(GameContent.itemBaseTypes.first)
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

        #expect(sanitized.items.map(\.id) == ["shared-id", "unique-id"])
    }

    @Test func sanitizeJourneyClampsInvalidStageAndChapterIDs() {
        var journey = JourneyProgressState.initial
        journey.activeChapterID = "missing-chapter"
        journey.activeStageID = "missing-stage"
        journey.completedStageIDs = ["chapter-1-stage-1", "missing-stage"]
        journey.claimedRewardStageIDs = ["missing-reward"]

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        #expect(sanitized.activeChapterID == "chapter-1")
        #expect(sanitized.activeStageID == "chapter-1-stage-2")
        #expect(sanitized.completedStageIDs == ["chapter-1-stage-1"])
        #expect(sanitized.claimedRewardStageIDs.isEmpty)
    }

    @Test func sanitizeJourneyAlignsActiveChapterWithActiveStage() {
        var journey = JourneyProgressState.initial
        journey.activeChapterID = "chapter-2"
        journey.activeStageID = "chapter-1-stage-2"
        journey.completedStageIDs = ["chapter-1-stage-1"]

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        #expect(sanitized.activeStageID == "chapter-1-stage-2")
        #expect(sanitized.activeChapterID == "chapter-1")
    }

    @Test func sanitizeJourneyMarksClaimedStagesAsCompleted() {
        var journey = JourneyProgressState.initial
        journey.claimedRewardStageIDs.insert("chapter-1-stage-1")

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        #expect(sanitized.completedStageIDs.contains("chapter-1-stage-1"))
        #expect(sanitized.claimedRewardStageIDs.contains("chapter-1-stage-1"))
    }

    @Test func sanitizeRosterFiltersInvalidUnlockIDs() {
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

        #expect(sanitized.unlockedHeroIDs == [PlayerRosterState.starterHeroID])
        #expect(sanitized.unlockedPetIDs == [PlayerRosterState.starterPetID])
    }

    @Test func sanitizeRosterFallsBackToStartersWhenUnlocksEmpty() {
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

        #expect(sanitized.unlockedHeroIDs == [PlayerRosterState.starterHeroID])
        #expect(sanitized.unlockedPetIDs == [PlayerRosterState.starterPetID])
        #expect(sanitized.activeHeroID == PlayerRosterState.starterHeroID)
        #expect(sanitized.activePetID == PlayerRosterState.starterPetID)
    }

    @Test func sanitizeRosterStripsUnknownCombatantAbilityLoadouts() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
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

        #expect(Set(sanitized.abilityLoadouts.keys) == ["knight"])
    }

    @Test func sanitizeRosterResolvesInvalidAbilityIDs() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
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

        #expect(
            sanitized.loadout(for: knight).skill?.id == knight.abilityLoadout.skill?.id
        )
    }

    @Test func sanitizeRosterPrunesMissingEquipmentItems() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.slot == .weapon })
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

        #expect(sanitized.roster.equipmentLoadout(for: knight).itemID(for: .weapon) == nil)
        #expect(sanitized.inventory.items.map(\.id) == ["weapon-id"])
    }

    @Test func sanitizeRosterStripsWeaponSlotFromPets() throws {
        let bear = try #require(GameContent.pets.first { $0.id == "bear" })
        let weaponBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .weapon })
        let trinketBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .trinket })
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

        #expect(loadout.itemID(for: .weapon) == nil)
        #expect(loadout.itemID(for: .trinket) == trinket.id)
    }

    @Test func sanitizeFullPipelineCombinesInventoryAndRoster() throws {
        let baseType = try #require(GameContent.itemBaseTypes.first)
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

        #expect(sanitized.inventory.items.map(\.id) == ["item-id"])
        #expect(sanitized.roster.unlockedHeroIDs == [PlayerRosterState.starterHeroID])
    }
}
