import Foundation
import TrinketContent

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

    public static func sanitizeJourney(
        _ journey: JourneyProgressState,
        chapters: [Chapter] = GameContent.chapters
    ) -> JourneyProgressState {
        let validChapterIDs = Set(chapters.map(\.id))
        let validStageIDs = Set(chapters.flatMap { $0.stages.map(\.id) })

        var sanitized = journey
        sanitized.completedStageIDs = journey.completedStageIDs.filter { validStageIDs.contains($0) }
        sanitized.claimedRewardStageIDs = journey.claimedRewardStageIDs.filter { validStageIDs.contains($0) }

        if let lastCompleted = journey.lastCompletedStageID,
           validStageIDs.contains(lastCompleted)
        {
            sanitized.lastCompletedStageID = lastCompleted
        } else {
            sanitized.lastCompletedStageID = sanitized.completedStageIDs.sorted().last
        }

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
        let combatantsByID = Dictionary(
            uniqueKeysWithValues: (GameContent.heroes + GameContent.pets).map { ($0.id, $0) }
        )

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

        if !unlockedHeroIDs.contains(sanitized.activeHeroID) {
            sanitized.activeHeroID = sanitized.unlockedHeroIDs.first ?? PlayerRosterState.starterHeroID
        }
        if !unlockedPetIDs.contains(sanitized.activePetID) {
            sanitized.activePetID = sanitized.unlockedPetIDs.first ?? PlayerRosterState.starterPetID
        }

        sanitized.equipmentLoadouts = [:]
        for (combatantID, savedLoadout) in roster.equipmentLoadouts {
            guard let combatant = combatantsByID[combatantID] else { continue }
            let resolved = savedLoadout
                .loadout(inventoryItemIDs: inventoryItemIDs)
                .sanitized(for: combatant, inventory: inventory.items)
            sanitized.equipmentLoadouts[combatantID] = SavedEquipmentLoadout(resolved)
        }

        sanitized.abilityLoadouts = roster.abilityLoadouts
        for combatantID in Array(sanitized.abilityLoadouts.keys) {
            guard let combatant = combatantsByID[combatantID] else {
                sanitized.abilityLoadouts.removeValue(forKey: combatantID)
                continue
            }
            let resolved = sanitized.abilityLoadouts[combatantID]?.loadout(
                defaults: combatant.abilityLoadout,
                choices: combatant.abilityChoices
            ) ?? combatant.abilityLoadout
            sanitized.abilityLoadouts[combatantID] = SavedAbilityLoadout(resolved)
        }

        return sanitized
    }
}
