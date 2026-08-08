import Foundation
import TrinketContent
import TrinketCore

public enum PlayerSaveSanitizer {
    public static func sanitize(_ save: PlayerSave) -> PlayerSave {
        var sanitized = save
        sanitized.inventory = sanitizeInventory(save.inventory)
        sanitized.roster = sanitizeRoster(save.roster, inventory: sanitized.inventory)
        sanitized.homestead = sanitizeHomestead(save.homestead)
        sanitized.journey = sanitizeJourney(save.journey)
        sanitized.spires = sanitizeSpires(save.spires)
        sanitized.labyrinth = sanitizeLabyrinth(
            save.labyrinth,
            eligibleRecruitEventIDs: sanitized.roster.eligibleRecruitEventIDs
        )
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
            if let stage = chapters.flatMap(\.stages).first(where: { $0.id == activeStageID }) {
                sanitized.activeChapterID = stage.chapterID
            }
        } else if let firstIncomplete = chapters
            .flatMap(\.stages)
            .first(where: { !sanitized.completedStageIDs.contains($0.id) }) {
            sanitized.activeStageID = firstIncomplete.id
            sanitized.activeChapterID = firstIncomplete.chapterID
        } else {
            sanitized.activeStageID = nil
            sanitized.activeChapterID = chapters.last?.id
                ?? JourneyProgressState.initial.activeChapterID
        }

        return sanitized
    }

    public static func sanitizeHomestead(_ homestead: PlayerHomesteadState) -> PlayerHomesteadState {
        var sanitized = homestead
        sanitized.resources = Dictionary(
            uniqueKeysWithValues: homestead.resources.compactMap { resource, quantity in
                guard resource != .gold else { return nil }
                return (resource, PlayerHomesteadState.clampedMaterialBalance(quantity))
            }
        )
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
        companionIDs: Set<String> = Set(GameContent.companions.map(\.id))
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

        return sanitized
    }

    public static func sanitizeSpires(
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

    public static func sanitizeLabyrinth(
        _ labyrinth: PlayerLabyrinthState,
        biomes: [LabyrinthBiomeDefinition] = GameContent.labyrinthBiomes,
        modifiers: [LabyrinthModifierDefinition] = GameContent.labyrinthModifiers,
        eligibleRecruitEventIDs: [String] = []
    ) -> PlayerLabyrinthState {
        let validBiomeIDs = Set(biomes.map(\.id.rawValue))
        var sanitized = labyrinth

        if sanitized.hasEntered,
           sanitized.hasMap,
           sanitized.mapVersion < LabyrinthGenerator.currentMapVersion {
            sanitized = regeneratedLabyrinth(
                from: sanitized,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs
            )
        }

        sanitized.clusters = sanitized.clusters.compactMap { cluster in
            guard validBiomeIDs.contains(cluster.biomeID.rawValue) else { return nil }
            return LabyrinthCluster(
                id: cluster.id,
                biomeID: cluster.biomeID,
                depthBand: max(0, cluster.depthBand),
                modifierIDs: [],
                nodeIDs: cluster.nodeIDs
            )
        }

        let validClusterIDs = Set(sanitized.clusters.map(\.id))
        sanitized.nodes = sanitized.nodes.filter { _, node in
            validClusterIDs.contains(node.clusterID) || node.id == LabyrinthGenerator.entranceNodeID
        }

        // Drop dangling edges and migrate legacy cluster maps to visible node-level floors.
        let existingNodes = sanitized.nodes
        for (id, node) in existingNodes {
            sanitized.nodes[id] = sanitizedLabyrinthNode(
                node,
                existingNodes: existingNodes,
                cluster: sanitized.cluster(id: node.clusterID),
                modifiers: modifiers
            )
        }

        // If map is corrupt/empty after sanitize but player had entered, rebuild from seed.
        if sanitized.hasEntered, sanitized.nodes.isEmpty {
            sanitized.ensureMap(
                seed: sanitized.worldSeed == 0 ? nil : sanitized.worldSeed,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs
            )
        }
        sanitized.mapVersion = LabyrinthGenerator.currentMapVersion
        return sanitized
    }

    private static func regeneratedLabyrinth(
        from legacy: PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String]
    ) -> PlayerLabyrinthState {
        let floorCount = max(1, legacy.currentFloorNumber)
        let seed = legacy.worldSeed == 0 ? LabyrinthGenerator.fallbackWorldSeed : legacy.worldSeed
        let generated = LabyrinthGenerator.makeMap(
            seed: seed,
            floorCount: floorCount,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs
        )
        var nodes = generated.nodes
        for (id, legacyNode) in legacy.nodes where legacyNode.isCleared {
            guard var node = nodes[id] else { continue }
            node.isCleared = true
            nodes[id] = node
        }
        ensureHistoricalFloorAccess(floorCount: floorCount, clusters: generated.clusters, nodes: &nodes)
        return PlayerLabyrinthState(
            worldSeed: seed,
            mapVersion: LabyrinthGenerator.currentMapVersion,
            hasEntered: legacy.hasEntered,
            clusters: generated.clusters,
            nodes: nodes
        )
    }

    private static func ensureHistoricalFloorAccess(
        floorCount: Int,
        clusters: [LabyrinthCluster],
        nodes: inout [String: LabyrinthNode]
    ) {
        guard floorCount > 1 else { return }
        for floor in 1 ..< floorCount {
            guard let cluster = clusters.first(where: { $0.depthBand == floor }),
                  let entryID = cluster.nodeIDs.first,
                  let bossID = cluster.nodeIDs.last
            else { continue }
            for nodeID in adjacentPath(
                from: entryID,
                to: bossID,
                nodeIDs: cluster.nodeIDs,
                nodes: nodes
            ) {
                guard var node = nodes[nodeID] else { break }
                node.isCleared = true
                nodes[nodeID] = node
            }
        }
    }

    private static func sanitizedLabyrinthNode(
        _ node: LabyrinthNode,
        existingNodes: [String: LabyrinthNode],
        cluster: LabyrinthCluster?,
        modifiers: [LabyrinthModifierDefinition]
    ) -> LabyrinthNode {
        let depth = max(0, node.depth)
        let type: LabyrinthNodeType = if node.type == .entrance || node.type.rawValue == "gate", depth > 0 {
            .boss
        } else {
            node.type.canonical
        }
        let enemyID = type == .boss && node.enemyID == nil
            ? cluster.flatMap { LabyrinthCatalog.biome(id: $0.biomeID)?.bossEnemyID }
            : node.enemyID
        return LabyrinthNode(
            id: node.id,
            type: type,
            enemyID: enemyID,
            depth: depth,
            clusterID: node.clusterID,
            gridPosition: node.gridPosition ?? legacyGridPosition(for: node, in: cluster),
            modifierIDs: normalizedModifierIDs(for: node, type: type, modifiers: modifiers),
            recruitEventID: node.recruitEventID,
            mysteryEventID: node.mysteryEventID,
            outgoingIDs: node.outgoingIDs.filter { existingNodes[$0] != nil },
            isCleared: node.isCleared,
            isRevealed: depth > 0 || node.isRevealed
        )
    }

    private static func normalizedModifierIDs(
        for node: LabyrinthNode,
        type: LabyrinthNodeType,
        modifiers: [LabyrinthModifierDefinition]
    ) -> [LabyrinthModifierID] {
        let applicable = modifiers.filter { $0.applies(to: type) }
        if let existing = node.modifierIDs.compactMap({ id in
            applicable.first { $0.id == id }
        }).first {
            return [existing.id]
        }
        guard !applicable.isEmpty else { return [] }
        if type == .battle || type == .boss {
            let index = Int(GameContent.stableSeed(for: node.id) % UInt64(applicable.count))
            return [applicable[index].id]
        }
        return [applicable[0].id]
    }

    private static func legacyGridPosition(
        for node: LabyrinthNode,
        in cluster: LabyrinthCluster?
    ) -> LabyrinthGridPosition {
        guard let cluster,
              let index = cluster.nodeIDs.firstIndex(of: node.id)
        else { return LabyrinthGridPosition(row: 0, column: 1) }
        if index == cluster.nodeIDs.count - 1 {
            return LabyrinthGridPosition(row: max(1, (index + 1) / 3), column: 1)
        }
        return LabyrinthGridPosition(row: index / 3, column: index % 3)
    }
}

private extension PlayerSaveSanitizer {
    static func adjacentPath(
        from sourceID: String,
        to targetID: String,
        nodeIDs: [String],
        nodes: [String: LabyrinthNode]
    ) -> [String] {
        var frontier = [sourceID]
        var nextIndex = 0
        var predecessor: [String: String] = [:]
        var visited: Set<String> = [sourceID]

        while nextIndex < frontier.count {
            let nodeID = frontier[nextIndex]
            nextIndex += 1
            if nodeID == targetID {
                break
            }
            guard let source = nodes[nodeID] else {
                continue
            }

            for candidateID in nodeIDs.sorted() {
                guard !visited.contains(candidateID),
                      let candidate = nodes[candidateID],
                      source.isAdjacent(to: candidate)
                else { continue }
                visited.insert(candidateID)
                predecessor[candidateID] = nodeID
                frontier.append(candidateID)
            }
        }

        guard visited.contains(targetID) else { return [] }
        var path = [targetID]
        while let first = path.first, let previous = predecessor[first] {
            path.insert(previous, at: path.startIndex)
        }
        return path.first == sourceID ? path : []
    }
}
