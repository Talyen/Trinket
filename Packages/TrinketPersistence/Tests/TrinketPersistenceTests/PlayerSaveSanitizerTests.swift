import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

@MainActor
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

        try #expect(sanitized.items.map(\.id) == ["shared-id", "unique-id"])
    }

    @Test func sanitizeHomesteadClampsMaterialBalances() throws {
        let homestead = PlayerHomesteadState(
            resources: [
                .wood: 1500,
                .stone: -3,
                .food: 40,
                .gold: 99
            ],
            nodeTiers: [.wheatField: 1]
        )

        let sanitized = PlayerSaveSanitizer.sanitizeHomestead(homestead)

        try #expect(sanitized.resources[.wood] == PlayerHomesteadState.maxMaterialBalance)
        try #expect(sanitized.resources[.stone] == 0)
        try #expect(sanitized.resources[.food] == 40)
        try #expect(sanitized.resources[.gold] == nil)
        try #expect(sanitized.nodeTiers[.wheatField] == 1)
    }

    @Test func sanitizeJourneyClampsInvalidStageAndChapterIDs() throws {
        var journey = JourneyProgressState.initial
        journey.activeChapterID = "missing-chapter"
        journey.activeStageID = "missing-stage"
        journey.completedStageIDs = ["chapter-1-stage-1", "missing-stage"]
        journey.claimedRewardStageIDs = ["missing-reward"]

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        try #expect(sanitized.activeChapterID == "chapter-1")
        try #expect(sanitized.activeStageID == "chapter-1-stage-2")
        try #expect(sanitized.completedStageIDs == ["chapter-1-stage-1"])
        try #expect(sanitized.claimedRewardStageIDs.isEmpty)
    }

    @Test func sanitizeJourneyAlignsActiveChapterWithActiveStage() throws {
        var journey = JourneyProgressState.initial
        journey.activeChapterID = "chapter-2"
        journey.activeStageID = "chapter-1-stage-2"
        journey.completedStageIDs = ["chapter-1-stage-1"]

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        try #expect(sanitized.activeStageID == "chapter-1-stage-2")
        try #expect(sanitized.activeChapterID == "chapter-1")
    }

    @Test func sanitizeJourneyAdvancesLegacyClearedChapter() throws {
        var journey = JourneyProgressState.initial
        journey.activeChapterID = "chapter-1"
        journey.activeStageID = nil
        journey.completedStageIDs = Set(GameContent.chapters[0].stages.map(\.id))
        journey.lastCompletedStageID = "chapter-1-stage-5"

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        try #expect(sanitized.activeChapterID == "chapter-2")
        try #expect(sanitized.activeStageID == "chapter-2-stage-1")
    }

    @Test func sanitizeJourneyMarksClaimedStagesAsCompleted() throws {
        var journey = JourneyProgressState.initial
        journey.claimedRewardStageIDs.insert("chapter-1-stage-1")

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        try #expect(sanitized.completedStageIDs.contains("chapter-1-stage-1"))
        try #expect(sanitized.claimedRewardStageIDs.contains("chapter-1-stage-1"))
    }

    @Test func sanitizeRosterFiltersInvalidUnlockIDs() throws {
        let roster = PlayerRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activeCompanionID: PlayerRosterState.starterCompanionID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID, "missing-hero"],
            unlockedCompanionIDs: [PlayerRosterState.starterCompanionID, "missing-companion"],
            abilityLoadouts: [:],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventory: .freshStart)

        try #expect(sanitized.unlockedHeroIDs == [PlayerRosterState.starterHeroID])
        try #expect(sanitized.unlockedCompanionIDs == [PlayerRosterState.starterCompanionID])
    }

    @Test func sanitizeRosterClampsGoldBalance() throws {
        var roster = PlayerRosterState.initial
        roster.gold = PlayerRosterState.maxGoldBalance + 1

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventory: .freshStart)

        try #expect(sanitized.gold == PlayerRosterState.maxGoldBalance)
    }

    @Test func sanitizeRosterFallsBackToStartersWhenUnlocksEmpty() throws {
        let roster = PlayerRosterState(
            activeHeroID: "wizard",
            activeCompanionID: "wolf",
            unlockedHeroIDs: ["missing-hero"],
            unlockedCompanionIDs: ["missing-companion"],
            abilityLoadouts: [:],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventory: .freshStart)

        try #expect(sanitized.unlockedHeroIDs == [PlayerRosterState.starterHeroID])
        try #expect(sanitized.unlockedCompanionIDs == [PlayerRosterState.starterCompanionID])
        try #expect(sanitized.activeHeroID == PlayerRosterState.starterHeroID)
        try #expect(sanitized.activeCompanionID == PlayerRosterState.starterCompanionID)
    }

    @Test func sanitizeRosterStripsUnknownCombatantAbilityLoadouts() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        var unknownLoadout = knight.abilityLoadout
        if let skill = knight.abilityChoices.abilities(for: .skill).first {
            unknownLoadout = unknownLoadout.selecting(skill)
        }
        let roster = PlayerRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activeCompanionID: PlayerRosterState.starterCompanionID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID],
            unlockedCompanionIDs: [PlayerRosterState.starterCompanionID],
            abilityLoadouts: [
                "knight": knight.abilityLoadout,
                "missing-combatant": unknownLoadout
            ],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventory: .freshStart)

        try #expect(Set(sanitized.abilityLoadouts.keys) == ["knight"])
    }

    @Test func sanitizeRosterResolvesInvalidAbilityIDs() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        var invalidLoadout = knight.abilityLoadout
        let missingAbility = Ability(
            id: "missing-ability",
            name: "Missing",
            tier: .skill,
            description: "Missing"
        )
        invalidLoadout = invalidLoadout.selecting(missingAbility)
        let roster = PlayerRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activeCompanionID: PlayerRosterState.starterCompanionID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID],
            unlockedCompanionIDs: [PlayerRosterState.starterCompanionID],
            abilityLoadouts: ["knight": invalidLoadout],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventory: .freshStart)

        try #expect(
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
            activeCompanionID: PlayerRosterState.starterCompanionID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID],
            unlockedCompanionIDs: [PlayerRosterState.starterCompanionID],
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

        try #expect(sanitized.roster.equipmentLoadout(for: knight).itemID(for: .weapon) == nil)
        try #expect(sanitized.inventory.items.map(\.id) == ["weapon-id"])
    }

    @Test func sanitizeRosterStripsWeaponSlotFromCompanions() throws {
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
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
            activeCompanionID: PlayerRosterState.starterCompanionID,
            unlockedHeroIDs: [PlayerRosterState.starterHeroID],
            unlockedCompanionIDs: [PlayerRosterState.starterCompanionID],
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

        try #expect(loadout.itemID(for: .weapon) == nil)
        try #expect(loadout.itemID(for: .trinket) == trinket.id)
    }

    @Test func sanitizeRosterStripsDuplicateItemAcrossCombatants() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        let wand = try #require(PlayerInventoryState.initial.item(matching: "wand-basic"))
        let roster = PlayerRosterState(
            activeHeroID: PlayerRosterState.starterHeroID,
            activeCompanionID: PlayerRosterState.starterCompanionID,
            unlockedHeroIDs: [knight.id, wizard.id, PlayerRosterState.starterHeroID],
            unlockedCompanionIDs: [PlayerRosterState.starterCompanionID],
            abilityLoadouts: [:],
            progressions: [:],
            equipmentLoadouts: [
                knight.id: EquipmentLoadout(itemIDsBySlot: [.weapon: wand.id]),
                wizard.id: EquipmentLoadout(itemIDsBySlot: [.weapon: wand.id])
            ],
            gold: 0
        )
        var save = PlayerSave.fresh
        save.inventory = PlayerInventoryState.initial
        save.roster = roster

        let sanitized = PlayerSaveSanitizer.sanitize(save)

        // Stable combatant-ID order: first claim wins.
        try #expect(sanitized.roster.equipmentLoadout(for: knight).itemID(for: .weapon) == wand.id)
        try #expect(sanitized.roster.equipmentLoadout(for: wizard).itemID(for: .weapon) == nil)
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

        try #expect(sanitized.inventory.items.map(\.id) == ["item-id"])
        try #expect(sanitized.roster.unlockedHeroIDs == [PlayerRosterState.starterHeroID])
    }
}
