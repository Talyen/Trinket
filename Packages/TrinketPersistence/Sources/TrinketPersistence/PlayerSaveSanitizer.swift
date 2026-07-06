import Foundation
import TrinketContent
import TrinketCore

public enum PlayerSaveSanitizer {
    public static func sanitize(_ save: PlayerSave) -> PlayerSave {
        var sanitized = save
        let inventory = sanitizeInventory(save.inventory.inventory())
        sanitized.inventory = SavedInventoryState(inventory)
        sanitized.roster = sanitizeRoster(
            sanitized.roster,
            inventory: inventory
        )
        sanitized.homestead = SavedHomesteadState(save.homestead.homestead())
        sanitized.journey = sanitizeJourney(save.journey)
        return sanitized
    }

    public static func validate(_ save: PlayerSave) throws {
        guard save.schemaVersion > 0, save.schemaVersion <= PlayerSave.currentSchemaVersion else {
            throw PlayerSavePersistenceError.invalidSave("Save schema version is out of range.")
        }
        guard save.roster.gold >= 0 else {
            throw PlayerSavePersistenceError.invalidSave("Roster gold cannot be negative.")
        }
        for (_, amount) in save.homestead.resources where amount < 0 {
            throw PlayerSavePersistenceError.invalidSave("Homestead resources cannot be negative.")
        }
        for (_, nodeTier) in save.homestead.nodeTiers where nodeTier < 0 {
            throw PlayerSavePersistenceError.invalidSave("Homestead node tiers cannot be negative.")
        }
        try validateProgressions(in: save.roster.progressions)
    }

    private static func validateProgressions(
        in progressions: [String: CombatantProgression]
    ) throws {
        for (combatantID, progression) in progressions {
            guard progression.level >= 1 else {
                throw PlayerSavePersistenceError.invalidSave(
                    "Combatant \(combatantID) level must be at least 1."
                )
            }
            guard progression.currentXP >= 0 else {
                throw PlayerSavePersistenceError.invalidSave(
                    "Combatant \(combatantID) current XP cannot be negative."
                )
            }
            guard progression.requiredXP > 0 else {
                throw PlayerSavePersistenceError.invalidSave(
                    "Combatant \(combatantID) required XP must be positive."
                )
            }
        }
    }

    public static func latestStageID(
        in completedStageIDs: Set<String>,
        chapters: [Chapter] = GameContent.chapters
    ) -> String? {
        chapters
            .flatMap(\.stages)
            .map(\.id)
            .filter { completedStageIDs.contains($0) }
            .last
    }

    public static func sanitizeJourney(
        _ journey: JourneyProgressState,
        chapters: [Chapter] = GameContent.chapters
    ) -> JourneyProgressState {
        let validChapterIDs = Set(chapters.map(\.id))
        let validStageIDs = Set(chapters.flatMap { $0.stages.map(\.id) })

        var sanitized = journey
        sanitized.completedStageIDs = journey.completedStageIDs.filter { validStageIDs.contains($0) }
        sanitized.claimedRewardStageIDs = journey.claimedRewardStageIDs.filter { validStageIDs.contains($0) }
        for stageID in sanitized.claimedRewardStageIDs {
            sanitized.completedStageIDs.insert(stageID)
        }
        sanitized.lastCompletedStageID = latestStageID(in: sanitized.completedStageIDs, chapters: chapters)

        if validChapterIDs.contains(sanitized.activeChapterID) {
            // keep
        } else {
            sanitized.activeChapterID = chapters.first?.id ?? JourneyProgressState.initial.activeChapterID
        }

        if let activeStageID = sanitized.activeStageID,
           validStageIDs.contains(activeStageID),
           !sanitized.completedStageIDs.contains(activeStageID)
        {
            sanitized.activeStageID = activeStageID
        } else {
            sanitized.activeStageID = chapters
                .flatMap(\.stages)
                .first { !sanitized.completedStageIDs.contains($0.id) }?
                .id
        }

        if let activeStageID = sanitized.activeStageID,
           let stage = chapters.flatMap(\.stages).first(where: { $0.id == activeStageID })
        {
            sanitized.activeChapterID = stage.chapterID
        }

        return sanitized
    }

    public static func sanitizeInventory(_ inventory: PlayerInventoryState) -> PlayerInventoryState {
        var seenIDs = Set<String>()
        let uniqueItems = inventory.items.filter { item in
            guard !seenIDs.contains(item.id) else { return false }
            seenIDs.insert(item.id)
            return true
        }
        return PlayerInventoryState(items: uniqueItems)
    }

    public static func sanitizeRoster(
        _ roster: SavedRosterState,
        inventory: PlayerInventoryState
    ) -> SavedRosterState {
        let inventoryItemIDs = Set(inventory.items.map(\.id))
        let validHeroIDs = Set(GameContent.heroes.map(\.id))
        let validPetIDs = Set(GameContent.pets.map(\.id))

        var sanitized = roster
        sanitized.unlockedHeroIDs = roster.unlockedHeroIDs.filter { validHeroIDs.contains($0) }
        sanitized.unlockedPetIDs = roster.unlockedPetIDs.filter { validPetIDs.contains($0) }

        if sanitized.unlockedHeroIDs.isEmpty {
            sanitized.unlockedHeroIDs = [PlayerRosterState.starterHeroID]
        }
        if sanitized.unlockedPetIDs.isEmpty {
            sanitized.unlockedPetIDs = [PlayerRosterState.starterPetID]
        }

        let unlockedHeroIDs = Set(sanitized.unlockedHeroIDs)
        let unlockedPetIDs = Set(sanitized.unlockedPetIDs)
        let (resolvedHeroID, resolvedPetID) = SavedRosterHydration.resolveActiveSelection(
            activeHeroID: sanitized.activeHeroID,
            activePetID: sanitized.activePetID,
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedPetIDs: unlockedPetIDs
        )
        sanitized.activeHeroID = resolvedHeroID
        sanitized.activePetID = resolvedPetID

        let resolvedEquipment = SavedRosterHydration.resolveEquipmentLoadouts(
            from: roster.equipmentLoadouts,
            inventoryItemIDs: inventoryItemIDs,
            inventoryItems: inventory.items
        )
        sanitized.equipmentLoadouts = resolvedEquipment.mapValues(SavedEquipmentLoadout.init)

        var abilityLoadouts = roster.abilityLoadouts
        for combatantID in Array(abilityLoadouts.keys) where SavedRosterHydration.combatantsByID[combatantID] == nil {
            abilityLoadouts.removeValue(forKey: combatantID)
        }
        sanitized.abilityLoadouts = SavedRosterHydration.resolveAbilityLoadouts(from: abilityLoadouts)
            .mapValues(SavedAbilityLoadout.init)

        return sanitized
    }
}
