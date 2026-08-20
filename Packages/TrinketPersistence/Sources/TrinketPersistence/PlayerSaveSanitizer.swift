import Foundation
import TrinketContent
import TrinketCore

public enum PlayerSaveSanitizer {
    public static func sanitize(_ save: PlayerSave) -> PlayerSave {
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

    public static let defaultHeroIDs: Set<String> = Set(GameContent.heroes.map(\.id))
    public static let defaultCompanionIDs: Set<String> = Set(GameContent.companions.map(\.id))
    public static let defaultChapterIDs: Set<String> = Set(GameContent.chapters.map(\.id))
    public static let defaultStageIDs: Set<String> = Set(GameContent.chapters.flatMap(\.stages).map(\.id))

    public static func sanitizeJourney(
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

    public static func sanitizeHomestead(_ homestead: PlayerHomesteadState) -> PlayerHomesteadState {
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

    public static func sanitizeInventory(_ inventory: PlayerInventoryState) -> PlayerInventoryState {
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

    public static func sanitizeRoster(
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

        sanitized.unlockedTalents = sanitizeUnlockedTalents(
            roster.unlockedTalents,
            validCombatantIDs: validHeroIDs.union(validCompanionIDs),
            progressions: sanitized.progressions
        )

        return sanitized
    }

    public static func sanitizeUnlockedTalents(
        _ talents: [String: Set<String>],
        validCombatantIDs: Set<String>,
        progressions: [String: CombatantProgression] = [:]
    ) -> [String: Set<String>] {
        var sanitized: [String: Set<String>] = [:]
        for (combatantID, nodeIDs) in talents {
            guard validCombatantIDs.contains(combatantID) else { continue }
            let validNodeIDs = CombatantTalentCatalog.validNodeIDs(for: combatantID)
            let remapped = Set(nodeIDs.map { remappedTalentNodeID($0) })
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

    /// Former Dodge/Stun tree node IDs for Rogue and Frost Whelp.
    static func remappedTalentNodeID(_ nodeID: String) -> String {
        if let mapped = talentNodeIDAliases[nodeID] {
            return mapped
        }
        return nodeID
    }

    private static let talentNodeIDAliases: [String: String] = {
        var aliases: [String: String] = [:]
        for tier in 1 ... 3 {
            for col in 1 ... 2 {
                aliases["rogue_dodge_t\(tier)_\(col)"] = "rogue_gold_t\(tier)_\(col)"
                aliases["frost_whelp_stun_t\(tier)_\(col)"] = "frost_whelp_dodge_t\(tier)_\(col)"
            }
        }
        return aliases
    }()

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
}

public extension PlayerSaveSanitizer {
    static func sanitizeLabyrinth(
        _ labyrinth: PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String] = []
    ) -> PlayerLabyrinthState {
        if labyrinth.isMapPayloadUnreadable {
            return labyrinth
        }

        var sanitized = labyrinth

        if sanitized.hasEntered,
           sanitized.hasMap,
           sanitized.mapVersion < LabyrinthGenerator.currentMapVersion {
            sanitized = regeneratedLabyrinth(
                from: sanitized,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs
            )
        }

        sanitized.clusters = sanitized.clusters.map { cluster in
            LabyrinthCluster(
                id: cluster.id,
                depthBand: max(0, cluster.depthBand),
                nodeIDs: cluster.nodeIDs
            )
        }

        let validClusterIDs = Set(sanitized.clusters.map(\.id))
        sanitized.nodes = sanitized.nodes.filter { _, node in
            validClusterIDs.contains(node.clusterID) || node.id == LabyrinthGenerator.entranceNodeID
        }

        let existingNodes = sanitized.nodes
        for (id, node) in existingNodes {
            sanitized.nodes[id] = sanitizedLabyrinthNode(
                node,
                existingNodes: existingNodes,
                cluster: sanitized.cluster(id: node.clusterID),
                worldSeed: sanitized.worldSeed
            )
        }

        // Rebuild empty entered maps unless the on-disk blob was unreadable.
        if sanitized.hasEntered, sanitized.nodes.isEmpty, !sanitized.isMapPayloadUnreadable {
            sanitized.ensureMap(
                seed: sanitized.worldSeed == 0 ? nil : sanitized.worldSeed,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs
            )
        }
        sanitized.mapVersion = LabyrinthGenerator.currentMapVersion
        return sanitized
    }
}

private extension PlayerSaveSanitizer {
    static func regeneratedLabyrinth(
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
        migrateLegacyFloorProgress(from: legacy, clusters: generated.clusters, nodes: &nodes)
        for (id, legacyNode) in legacy.nodes {
            guard let generatedNode = nodes[id] else { continue }
            nodes[id] = LabyrinthNode(
                id: generatedNode.id,
                type: generatedNode.type,
                enemyID: generatedNode.enemyID,
                depth: generatedNode.depth,
                clusterID: generatedNode.clusterID,
                gridPosition: generatedNode.gridPosition,
                modifierIDs: generatedNode.modifierIDs,
                recruitEventID: legacyNode.recruitEventID ?? generatedNode.recruitEventID,
                mysteryEventID: legacyNode.mysteryEventID ?? generatedNode.mysteryEventID,
                outgoingIDs: generatedNode.outgoingIDs,
                isCleared: generatedNode.isCleared || legacyNode.isCleared,
                isRevealed: generatedNode.isRevealed || legacyNode.isRevealed
            )
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

    static func migrateLegacyFloorProgress(
        from legacy: PlayerLabyrinthState, clusters: [LabyrinthCluster], nodes: inout [String: LabyrinthNode]
    ) {
        for cluster in clusters where cluster.depthBand > 0 {
            guard let legacyCluster = legacy.clusters.first(where: { $0.depthBand == cluster.depthBand }),
                  Set(legacyCluster.nodeIDs).isDisjoint(with: cluster.nodeIDs)
            else { continue }
            let legacyFloorNodes = legacyCluster.nodeIDs.compactMap { legacy.nodes[$0] }
            let clearedNonBossCount = legacyFloorNodes.count { $0.isCleared && $0.type.canonical != .boss }
            guard let entryID = cluster.nodeIDs.first else { continue }
            var migrationOrder: [String] = []
            for targetID in cluster.nodeIDs where nodes[targetID]?.type.canonical != .boss {
                let path = adjacentPath(from: entryID, to: targetID, nodeIDs: cluster.nodeIDs, nodes: nodes)
                for nodeID in path where nodes[nodeID]?.type.canonical != .boss && !migrationOrder.contains(nodeID) {
                    migrationOrder.append(nodeID)
                }
            }
            for nodeID in migrationOrder.prefix(clearedNonBossCount) {
                guard var node = nodes[nodeID] else { continue }
                node.isCleared = true
                nodes[nodeID] = node
            }
            guard legacyFloorNodes.contains(where: { $0.isCleared && $0.type.canonical == .boss }),
                  let bossID = cluster.nodeIDs.first(where: { nodes[$0]?.type.canonical == .boss }),
                  var boss = nodes[bossID]
            else { continue }
            boss.isCleared = true
            nodes[bossID] = boss
        }
    }

    static func ensureHistoricalFloorAccess(
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

    static func sanitizedLabyrinthNode(
        _ node: LabyrinthNode,
        existingNodes: [String: LabyrinthNode],
        cluster: LabyrinthCluster?,
        worldSeed: UInt64
    ) -> LabyrinthNode {
        let depth = max(0, node.depth)
        let type: LabyrinthNodeType = if node.type == .entrance || node.type.rawValue == "gate", depth > 0 {
            .boss
        } else {
            node.type.canonical
        }
        let enemyID: String? = if type == .boss, node.enemyID == nil {
            LabyrinthCatalog.fallbackBossEnemyID(worldSeed: worldSeed, nodeID: node.id)
        } else {
            node.enemyID
        }
        return LabyrinthNode(
            id: node.id,
            type: type,
            enemyID: enemyID,
            depth: depth,
            clusterID: node.clusterID,
            gridPosition: node.gridPosition ?? legacyGridPosition(for: node, in: cluster),
            modifierIDs: LabyrinthCatalog.resolvedModifierIDs(
                for: type,
                enemyID: enemyID,
                existingModifierIDs: node.modifierIDs,
                worldSeed: worldSeed,
                nodeID: node.id
            ),
            recruitEventID: node.recruitEventID,
            mysteryEventID: node.mysteryEventID,
            outgoingIDs: node.outgoingIDs.filter { existingNodes[$0] != nil },
            isCleared: node.isCleared,
            isRevealed: depth > 0 || node.isRevealed
        )
    }

    static func legacyGridPosition(
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
        let candidateNodes: [(id: String, node: LabyrinthNode)] = nodeIDs.sorted().compactMap { id in
            nodes[id].map { (id, $0) }
        }

        while nextIndex < frontier.count {
            let nodeID = frontier[nextIndex]
            nextIndex += 1
            if nodeID == targetID {
                break
            }
            guard let source = nodes[nodeID] else {
                continue
            }

            for (candidateID, candidate) in candidateNodes {
                guard !visited.contains(candidateID), source.isAdjacent(to: candidate) else { continue }
                visited.insert(candidateID)
                predecessor[candidateID] = nodeID
                frontier.append(candidateID)
            }
        }

        guard visited.contains(targetID) else { return [] }
        var path = [targetID]
        while let current = path.last, let previous = predecessor[current] {
            path.append(previous)
        }
        path.reverse()
        return path.first == sourceID ? path : []
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
