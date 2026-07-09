import Foundation
import TrinketContent
import TrinketCore

public enum PlayerSaveSanitizer {
    public static func sanitize(_ save: PlayerSave) -> PlayerSave {
        var sanitized = save
        sanitized.inventory = sanitizeInventory(save.inventory)
        sanitized.roster = sanitizeRoster(save.roster, inventory: sanitized.inventory)
        sanitized.homestead = save.homestead
        sanitized.journey = sanitizeJourney(save.journey)
        sanitized.collectionAttention = sanitizeCollectionAttention(
            save.collectionAttention,
            roster: sanitized.roster,
            inventory: sanitized.inventory
        )
        sanitized.aspects = sanitizeAspects(save.aspects)
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
            .last { completedStageIDs.contains($0) }
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
           !sanitized.completedStageIDs.contains(activeStageID) {
            sanitized.activeStageID = activeStageID
        } else {
            sanitized.activeStageID = chapters
                .flatMap(\.stages)
                .first { !sanitized.completedStageIDs.contains($0.id) }?
                .id
        }

        if let activeStageID = sanitized.activeStageID,
           let stage = chapters.flatMap(\.stages).first(where: { $0.id == activeStageID }) {
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
        _ roster: PlayerRosterState,
        inventory: PlayerInventoryState,
        heroIDs: Set<String> = Set(GameContent.heroes.map(\.id)),
        petIDs: Set<String> = Set(GameContent.pets.map(\.id))
    ) -> PlayerRosterState {
        let inventoryItemIDs = Set(inventory.items.map(\.id))
        let validHeroIDs = heroIDs
        let validPetIDs = petIDs

        var sanitized = roster
        sanitized.unlockedHeroIDs = roster.unlockedHeroIDs.filter { validHeroIDs.contains($0) }
        sanitized.unlockedPetIDs = roster.unlockedPetIDs.filter { validPetIDs.contains($0) }

        if sanitized.unlockedHeroIDs.isEmpty {
            sanitized.unlockedHeroIDs = [PlayerRosterState.starterHeroID]
        }
        if sanitized.unlockedPetIDs.isEmpty {
            sanitized.unlockedPetIDs = [PlayerRosterState.starterPetID]
        }

        let (resolvedHeroID, resolvedPetID) = RosterHydration.resolveActiveSelection(
            activeHeroID: sanitized.activeHeroID,
            activePetID: sanitized.activePetID,
            unlockedHeroIDs: sanitized.unlockedHeroIDs,
            unlockedPetIDs: sanitized.unlockedPetIDs
        )
        sanitized.activeHeroID = resolvedHeroID
        sanitized.activePetID = resolvedPetID

        let wireEquipment = roster.equipmentLoadouts.mapValues(WireEquipmentLoadout.init)
        sanitized.equipmentLoadouts = RosterHydration.resolveEquipmentLoadouts(
            from: wireEquipment,
            inventoryItemIDs: inventoryItemIDs,
            inventoryItems: inventory.items
        )

        var wireAbility = roster.abilityLoadouts.mapValues(WireAbilityLoadout.init)
        for combatantID in Array(wireAbility.keys) where RosterHydration.combatantsByID[combatantID] == nil {
            wireAbility.removeValue(forKey: combatantID)
        }
        sanitized.abilityLoadouts = RosterHydration.resolveAbilityLoadouts(from: wireAbility)

        return sanitized
    }

    public static func sanitizeCollectionAttention(
        _ attention: PlayerCollectionAttentionState,
        roster: PlayerRosterState,
        inventory: PlayerInventoryState
    ) -> PlayerCollectionAttentionState {
        let unlockedCombatantIDs = roster.unlockedHeroIDs.union(roster.unlockedPetIDs)
        let ownedItemIDs = Set(inventory.items.map(\.id))
        let ownedTemplateIDs = Set(inventory.items.map(\.templateID))
        var sanitized = attention
        sanitized.viewedCombatantIDs = attention.viewedCombatantIDs.intersection(unlockedCombatantIDs)
        sanitized.viewedItemIDs = attention.viewedItemIDs.intersection(ownedItemIDs)
        sanitized.viewedItemTemplateIDs = attention.viewedItemTemplateIDs.intersection(ownedTemplateIDs)
        // Starters are always acknowledged — they are not discovery signals.
        if unlockedCombatantIDs.contains(PlayerRosterState.starterHeroID) {
            sanitized.viewedCombatantIDs.insert(PlayerRosterState.starterHeroID)
        }
        if unlockedCombatantIDs.contains(PlayerRosterState.starterPetID) {
            sanitized.viewedCombatantIDs.insert(PlayerRosterState.starterPetID)
        }
        return sanitized
    }

    public static func sanitizeAspects(
        _ aspects: PlayerAspectsState,
        catalog: [AspectDefinition] = GameContent.aspects
    ) -> PlayerAspectsState {
        let validIDs = Set(catalog.map(\.id.rawValue))
        let floorCounts = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id.rawValue, $0.floorCount) })
        var sanitized: [String: Int] = [:]
        for (aspectID, floor) in aspects.highestClearedFloorByAspectID {
            guard validIDs.contains(aspectID) else { continue }
            let maxFloor = floorCounts[aspectID] ?? 0
            sanitized[aspectID] = min(max(floor, 0), maxFloor)
        }
        return PlayerAspectsState(highestClearedFloorByAspectID: sanitized)
    }
}
