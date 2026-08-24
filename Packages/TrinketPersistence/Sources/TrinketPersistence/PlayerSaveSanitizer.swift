import Foundation
import TrinketContent
import TrinketCore

enum PlayerSaveSanitizer {
    static func sanitize(_ save: PlayerSave) -> PlayerSave {
        sanitize(save, changedSlices: .all)
    }

    /// Sanitizes only the mutated slices. Unchanged slices are skipped because
    /// every sanitizer is idempotent for already-normalized values; the roster
    /// sanitizer still re-runs when inventory changed (it resolves loadouts
    /// against inventory item ids), and the labyrinth sanitizer always sees the
    /// sanitized roster for recruit eligibility.
    static func sanitize(_ save: PlayerSave, changedSlices: PlayerSaveSlice) -> PlayerSave {
        var sanitized = save
        sanitized.worldSeed = resolvedWorldSeed(save)
        let labyrinthNeedsWorldSeed = !sanitized.labyrinth.hasMap || sanitized.labyrinth.worldSeed == 0
        if !sanitized.labyrinth.isMapPayloadUnreadable, labyrinthNeedsWorldSeed {
            sanitized.labyrinth.worldSeed = sanitized.worldSeed
        }
        if changedSlices.contains(.inventory) {
            sanitized.inventory = sanitizeInventory(save.inventory)
        }
        if changedSlices.contains(.roster) || changedSlices.contains(.inventory) {
            sanitized.roster = sanitizeRoster(save.roster, inventory: sanitized.inventory)
        }
        if changedSlices.contains(.homestead) {
            sanitized.homestead = sanitizeHomestead(save.homestead)
        }
        if changedSlices.contains(.journey) {
            sanitized.journey = sanitizeJourney(save.journey)
        }
        if changedSlices.contains(.spires) {
            sanitized.spires = sanitizeSpires(save.spires)
        }
        if changedSlices.contains(.labyrinth) {
            sanitized.labyrinth = sanitizeLabyrinth(
                sanitized.labyrinth,
                eligibleRecruitEventIDs: sanitized.roster.eligibleRecruitEventIDs
            )
        }
        return sanitized
    }

    /// Resolves the save's world seed. Assign-once semantics: new games get
    /// their random seed pinned at construction (`PlayerSave.fresh`); this only
    /// fills in seeds for saves missing one (adopting the labyrinth map's seed
    /// first). Both store entry points persist immediately after sanitizing, so
    /// a seed is never invented twice for the same save.
    static func resolvedWorldSeed(_ save: PlayerSave) -> UInt64 {
        if save.worldSeed != 0 {
            return save.worldSeed
        }
        if save.labyrinth.hasMap {
            let existing = save.labyrinth.worldSeed
            return existing == 0 ? LabyrinthGenerator.fallbackWorldSeed : existing
        }
        return PlayerSave.makeWorldSeed()
    }

    static func validate(_ save: PlayerSave) throws {
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
        try validateEncodedAffixPowers(save.inventory)
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

    static let defaultHeroIDs: Set<String> = Set(GameContent.heroes.map(\.id))
    static let defaultCompanionIDs: Set<String> = Set(GameContent.companions.map(\.id))
    static let defaultChapterIDs: Set<String> = Set(GameContent.chapters.map(\.id))
    static let defaultStageIDs: Set<String> = Set(GameContent.chapters.flatMap(\.stages).map(\.id))

    static func sanitizeJourney(
        _ journey: JourneyProgressState,
        chapters: [Chapter] = GameContent.chapters
    ) -> JourneyProgressState {
        let validChapterIDs = chapters == GameContent.chapters ? defaultChapterIDs : Set(chapters.map(\.id))
        let allStages = chapters.flatMap(\.stages)
        let validStageIDs = chapters == GameContent.chapters ? defaultStageIDs : Set(allStages.map(\.id))

        var sanitized = journey
        sanitized.completedStageIDs = journey.completedStageIDs.filter { validStageIDs.contains($0) }
        sanitized.claimedRewardStageIDs = journey.claimedRewardStageIDs.filter { validStageIDs.contains($0) }
        for stageID in sanitized.claimedRewardStageIDs {
            sanitized.completedStageIDs.insert(stageID)
        }
        sanitized.pinnedMysteryEventIDs = journey.pinnedMysteryEventIDs.filter { stageID, eventID in
            guard validStageIDs.contains(stageID), !eventID.isEmpty else { return false }
            return GameContent.mysteryEvent(matching: eventID) != nil
                || GameContent.recruitEvent(matching: eventID) != nil
        }

        if validChapterIDs.contains(sanitized.activeChapterID) {
            // keep
        } else {
            sanitized.activeChapterID = chapters.first?.id ?? JourneyProgressState.initial.activeChapterID
        }

        if let activeStageID = sanitized.activeStageID,
           validStageIDs.contains(activeStageID),
           !sanitized.completedStageIDs.contains(activeStageID) {
            sanitized.activeStageID = activeStageID
            if let stage = allStages.first(where: { $0.id == activeStageID }) {
                sanitized.activeChapterID = stage.chapterID
            }
        } else if let firstIncomplete = allStages.first(where: { !sanitized.completedStageIDs.contains($0.id) }) {
            sanitized.activeStageID = firstIncomplete.id
            sanitized.activeChapterID = firstIncomplete.chapterID
        } else {
            sanitized.activeStageID = nil
            sanitized.activeChapterID = chapters.last?.id
                ?? JourneyProgressState.initial.activeChapterID
        }

        return sanitized
    }

    static func sanitizeHomestead(_ homestead: PlayerHomesteadState) -> PlayerHomesteadState {
        var sanitized = homestead
        sanitized.pendingProduction = Dictionary(
            uniqueKeysWithValues: homestead.pendingProduction.compactMap { resource, quantity in
                guard quantity.isFinite, quantity > 0 else { return nil }
                if resource == .gold {
                    return (resource, min(quantity, Double(PlayerRosterState.maxGoldBalance)))
                }
                return (resource, quantity)
            }
        )
        sanitized.resources = Dictionary(
            uniqueKeysWithValues: homestead.resources.compactMap { resource, quantity in
                guard resource != .gold else { return nil }
                return (resource, max(0, quantity))
            }
        )
        sanitized.nodeTiers = Dictionary(
            uniqueKeysWithValues: homestead.nodeTiers.compactMap { nodeID, tier in
                guard let maxTier = HomesteadNodeCatalog.maxTierByNodeID[nodeID] else { return nil }
                return (nodeID, min(max(tier, 0), maxTier))
            }
        )
        return sanitized
    }

    static func sanitizeInventory(_ inventory: PlayerInventoryState) -> PlayerInventoryState {
        var seenIDs = Set<String>()
        var seenTrinketIDs = Set<String>()
        let uniqueItems = inventory.items.filter { item in
            guard !seenIDs.contains(item.id) else { return false }
            if item.isTrinket {
                guard seenTrinketIDs.insert(item.templateID).inserted else { return false }
            }
            seenIDs.insert(item.id)
            return true
        }
        return PlayerInventoryState(items: uniqueItems)
    }

    static func sanitizeRoster(
        _ roster: PlayerRosterState,
        inventory: PlayerInventoryState,
        heroIDs: Set<String> = Self.defaultHeroIDs,
        companionIDs: Set<String> = Self.defaultCompanionIDs
    ) -> PlayerRosterState {
        let inventoryItemIDs = Set(inventory.items.map(\.id))
        let validHeroIDs = heroIDs
        let validCompanionIDs = companionIDs

        var sanitized = roster
        sanitized.gold = PlayerRosterState.clampedGoldBalance(roster.gold)
        sanitized.unlockedHeroIDs = roster.unlockedHeroIDs.filter { validHeroIDs.contains($0) }
        sanitized.unlockedCompanionIDs = roster.unlockedCompanionIDs.filter { validCompanionIDs.contains($0) }

        if sanitized.unlockedHeroIDs.isEmpty {
            sanitized.unlockedHeroIDs = [PlayerRosterState.starterHeroID]
        }
        if sanitized.unlockedCompanionIDs.isEmpty {
            sanitized.unlockedCompanionIDs = [PlayerRosterState.starterCompanionID]
        }

        let (resolvedHeroID, resolvedCompanionID) = RosterHydration.resolveActiveSelection(
            activeHeroID: sanitized.activeHeroID,
            activeCompanionID: sanitized.activeCompanionID,
            unlockedHeroIDs: sanitized.unlockedHeroIDs,
            unlockedCompanionIDs: sanitized.unlockedCompanionIDs
        )
        sanitized.activeHeroID = resolvedHeroID
        sanitized.activeCompanionID = resolvedCompanionID

        sanitized.equipmentLoadouts = RosterHydration.resolveEquipmentLoadouts(
            from: roster.equipmentLoadouts,
            inventoryItemIDs: inventoryItemIDs,
            inventoryItems: inventory.items
        )

        sanitized.abilityLoadouts = RosterHydration.resolveAbilityLoadouts(
            from: roster.abilityLoadouts
        )

        sanitized.progressions = sanitizeProgressions(
            roster.progressions,
            validCombatantIDs: validHeroIDs.union(validCompanionIDs)
        )

        sanitized.unlockedTalents = sanitizeUnlockedTalents(
            roster.unlockedTalents,
            validCombatantIDs: validHeroIDs.union(validCompanionIDs),
            progressions: sanitized.progressions
        )

        return sanitized
    }

    static func sanitizeUnlockedTalents(
        _ talents: [String: Set<String>],
        validCombatantIDs: Set<String>,
        progressions: [String: CombatantProgression] = [:]
    ) -> [String: Set<String>] {
        var sanitized: [String: Set<String>] = [:]
        for (combatantID, nodeIDs) in talents {
            guard validCombatantIDs.contains(combatantID) else { continue }
            let validNodeIDs = CombatantTalentCatalog.validNodeIDs(for: combatantID)
            let remapped = Set(nodeIDs.map { LegacyIDRemap.remappedTalentNodeID($0) })
            var filtered = remapped.intersection(validNodeIDs)
            if let budget = progressions[combatantID]?.totalTalentPoints {
                filtered = CombatantTalentCatalog.config(for: combatantID)
                    .cappedUnlocks(filtered, budget: budget)
            }
            if !filtered.isEmpty {
                sanitized[combatantID] = filtered
            }
        }
        return sanitized
    }

    static func sanitizeProgressions(
        _ progressions: [String: CombatantProgression],
        validCombatantIDs: Set<String>
    ) -> [String: CombatantProgression] {
        var sanitized: [String: CombatantProgression] = [:]
        for (combatantID, progression) in progressions {
            guard validCombatantIDs.contains(combatantID) else { continue }
            let level = max(1, progression.level)
            let requiredXP = CombatantProgression.requiredXP(forLevel: level)
            let currentXP = min(max(0, progression.currentXP), requiredXP)
            sanitized[combatantID] = CombatantProgression(
                level: level,
                currentXP: currentXP,
                requiredXP: requiredXP
            )
        }
        return sanitized
    }

    static func sanitizeSpires(
        _ spires: PlayerSpiresState,
        catalog: [SpireDefinition] = GameContent.spires
    ) -> PlayerSpiresState {
        let validIDs = Set(catalog.map(\.id.rawValue))
        let floorCounts = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id.rawValue, $0.floorCount) })
        var sanitized: [String: Int] = [:]
        for (spireID, floor) in spires.highestClearedFloorBySpireID {
            guard validIDs.contains(spireID) else { continue }
            let maxFloor = floorCounts[spireID] ?? 0
            sanitized[spireID] = min(max(floor, 0), maxFloor)
        }
        return PlayerSpiresState(highestClearedFloorBySpireID: sanitized)
    }
}

private func validateEncodedAffixPowers(_ inventory: PlayerInventoryState) throws {
    for item in inventory.items {
        guard let powers = item.affixPowers else { continue }
        do {
            _ = try ItemAffixPowerCoding.encode(powers)
        } catch {
            throw PlayerSavePersistenceError.invalidSave(
                "Inventory item \(item.id) affix powers could not be encoded."
            )
        }
    }
}
