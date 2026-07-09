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
        sanitized.aspects = sanitizeAspects(save.aspects)
        sanitized.labyrinth = sanitizeLabyrinth(save.labyrinth)
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

    public static func sanitizeLabyrinth(
        _ labyrinth: PlayerLabyrinthState,
        biomes: [LabyrinthBiomeDefinition] = GameContent.labyrinthBiomes,
        modifiers: [LabyrinthModifierDefinition] = GameContent.labyrinthModifiers
    ) -> PlayerLabyrinthState {
        let validBiomeIDs = Set(biomes.map(\.id.rawValue))
        let validModifierIDs = Set(modifiers.map(\.id.rawValue))
        var sanitized = labyrinth
        sanitized.deepestDepth = max(0, sanitized.deepestDepth)
        sanitized.discoveredBiomeIDs = Set(sanitized.discoveredBiomeIDs.filter { validBiomeIDs.contains($0) })
        sanitized.discoveredModifierIDs = Set(sanitized.discoveredModifierIDs.filter { validModifierIDs.contains($0) })
        sanitized.claimedMilestoneDepths = Set(
            sanitized.claimedMilestoneDepths.filter { LabyrinthCompletion.milestoneDepths.contains($0) }
        )

        sanitized.clusters = sanitized.clusters.compactMap { cluster in
            guard validBiomeIDs.contains(cluster.biomeID.rawValue) else { return nil }
            let filteredModifiers = cluster.modifierIDs.filter { validModifierIDs.contains($0.rawValue) }
            return LabyrinthCluster(
                id: cluster.id,
                biomeID: cluster.biomeID,
                depthBand: max(0, cluster.depthBand),
                modifierIDs: filteredModifiers,
                nodeIDs: cluster.nodeIDs
            )
        }

        let validClusterIDs = Set(sanitized.clusters.map(\.id))
        sanitized.nodes = sanitized.nodes.filter { _, node in
            validClusterIDs.contains(node.clusterID) || node.id == LabyrinthGenerator.entranceNodeID
        }

        // Drop dangling outgoing edges; collapse legacy `.event` into `.mystery`.
        for (id, node) in sanitized.nodes {
            let outgoing = node.outgoingIDs.filter { sanitized.nodes[$0] != nil }
            let failCount = max(0, node.failCount)
            let depth = max(0, node.depth)
            let type = node.type.canonical
            if type != node.type || outgoing != node.outgoingIDs || failCount != node.failCount
                || depth != node.depth {
                sanitized.nodes[id] = LabyrinthNode(
                    id: node.id,
                    type: type,
                    enemyID: node.enemyID,
                    depth: depth,
                    clusterID: node.clusterID,
                    outgoingIDs: outgoing,
                    isCleared: node.isCleared,
                    isRevealed: node.isRevealed,
                    failCount: failCount
                )
            }
        }

        // If map is corrupt/empty after sanitize but player had entered, rebuild from seed.
        if sanitized.hasEntered, sanitized.nodes.isEmpty {
            sanitized.ensureMap(seed: sanitized.worldSeed == 0 ? nil : sanitized.worldSeed)
        }
        return sanitized
    }
}
