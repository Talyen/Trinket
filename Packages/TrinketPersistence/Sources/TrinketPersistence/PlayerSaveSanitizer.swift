import Foundation
import os
import TrinketContent
import TrinketCore

private let sanitizerLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "PlayerSaveSanitizer",
)

enum PlayerSaveSanitizer {
    static func sanitize(_ save: PlayerSave) -> PlayerSave {
        sanitize(save, changedSlices: .all)
    }

    /// Single sanitize→validate entry for commit, reset, and cloud-restore
    /// paths. Doctrine is heal-locally / reject-remotely: local callers pass
    /// a sanitize that repairs (negative gold, duplicates, ghost equipment,
    /// stale stage IDs, unreadable maps) and validation is the safety net
    /// for what repair cannot heal (schema mismatch, unencodable powers);
    /// cloud-restore callers rely on the same validation to refuse corrupt
    /// snapshots before they can propagate. The store-open path deliberately
    /// uses sanitize-only so a locally readable save always loads.
    static func sanitizeAndValidate(_ save: PlayerSave, changedSlices: PlayerSaveSlice = .all) throws -> PlayerSave {
        let sanitized = sanitize(save, changedSlices: changedSlices)
        #if DEBUG
        for (_, progression) in sanitized.roster.progressions {
            assert(
                progression.level >= 1 && progression.currentXP >= 0 && progression.requiredXP > 0,
                "sanitizeProgressions must heal level/XP/requiredXP; validate skips the redundant check",
            )
        }
        #endif
        try validate(sanitized)
        return sanitized
    }

    static func sanitize(_ save: PlayerSave, changedSlices: PlayerSaveSlice) -> PlayerSave {
        var sanitized = save
        sanitized.worldSeed = resolvedWorldSeed(save, seedIfMissing: changedSlices.contains(.root))
        if changedSlices.contains(.root) {
            sanitized.corruptionAltarCooldownRemaining = max(0, save.corruptionAltarCooldownRemaining)
        }
        if changedSlices.contains(.labyrinth),
           !sanitized.labyrinth.isMapPayloadUnreadable,
           save.worldSeed == 0 || !sanitized.labyrinth.hasMap || sanitized.labyrinth.worldSeed == 0 {
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
        if changedSlices.contains(.voyage) {
            sanitized.voyage = save.voyage.sanitized()
        }
        if changedSlices.contains(.contracts) {
            sanitized.contracts = save.contracts.sanitized()
        }
        if changedSlices.contains(.labyrinth) {
            sanitized.labyrinth = sanitizeLabyrinth(
                sanitized.labyrinth,
                eligibleRecruitEventIDs: sanitized.roster.eligibleRecruitEventIDs,
                eligibleRewards: RewardOwnership(sanitized).eligibleModifiers,
            )
        }
        return sanitized
    }

    static func resolvedWorldSeed(_ save: PlayerSave, seedIfMissing: Bool = true) -> UInt64 {
        if save.worldSeed != 0 {
            return save.worldSeed
        }
        if save.labyrinth.hasMap {
            let existing = save.labyrinth.worldSeed
            return existing == 0 ? LabyrinthGenerator.fallbackWorldSeed : existing
        }
        guard seedIfMissing else { return 0 }
        return PlayerSave.makeWorldSeed()
    }

    static func validate(_ save: PlayerSave) throws {
        guard save.schemaVersion == PlayerSave.currentSchemaVersion else {
            throw PlayerSavePersistenceError.invalidSave("Unsupported save schema version.")
        }
        guard !save.labyrinth.hasMap || save.labyrinth.mapVersion == LabyrinthGenerator.currentMapVersion else {
            throw PlayerSavePersistenceError.invalidSave("Unsupported Labyrinth map version.")
        }
        guard save.roster.gold >= 0 else {
            throw PlayerSavePersistenceError.invalidSave("Roster gold cannot be negative.")
        }
        guard save.corruptionAltarCooldownRemaining >= 0 else {
            throw PlayerSavePersistenceError.invalidSave("Corruption altar cooldown cannot be negative.")
        }
        for (_, amount) in save.homestead.resources where amount < 0 {
            throw PlayerSavePersistenceError.invalidSave("Homestead resources cannot be negative.")
        }
        for (_, nodeTier) in save.homestead.nodeTiers where nodeTier < 0 {
            throw PlayerSavePersistenceError.invalidSave("Homestead node tiers cannot be negative.")
        }
        // Progressions are healed by sanitizeProgressions (level >= 1, XP clamped,
        // requiredXP recomputed), so validate skips the redundant sub-check; the
        // DEBUG assert in sanitizeAndValidate guards the post-sanitize invariant.
        try validateEncodedAffixPowers(save.inventory)
    }

    static func sanitizeJourney(
        _ journey: JourneyProgressState,
        chapters: [Chapter]? = nil,
    ) -> JourneyProgressState {
        let activeChapters = chapters ?? GameContent.chapters
        let validChapterIDs: Set<String>
        let allStages: [Stage]
        let validStageIDs: Set<String>

        if let chapters {
            validChapterIDs = Set(chapters.map(\.id))
            allStages = chapters.flatMap(\.stages)
            validStageIDs = Set(allStages.map(\.id))
        } else {
            validChapterIDs = Set(GameContent.chapters.map(\.id))
            allStages = GameContent.chapters.flatMap(\.stages)
            validStageIDs = Set(allStages.map(\.id))
        }

        var sanitized = journey
        let beforeCompleted = journey.completedStageIDs.count
        let beforeClaimed = journey.claimedRewardStageIDs.count
        sanitized.completedStageIDs = journey.completedStageIDs.filtered(to: validStageIDs)
        sanitized.claimedRewardStageIDs = journey.claimedRewardStageIDs.filtered(to: validStageIDs)
        if sanitized.completedStageIDs.count != beforeCompleted || sanitized.claimedRewardStageIDs.count != beforeClaimed {
            sanitizerLogger.info("Sanitized journey: dropped invalid stage IDs")
        }
        for stageID in sanitized.claimedRewardStageIDs {
            sanitized.completedStageIDs.insert(stageID)
        }
        let beforePinned = journey.pinnedMysteryEventIDs.count
        sanitized.pinnedMysteryEventIDs = journey.pinnedMysteryEventIDs.filter { stageID, eventID in
            guard validStageIDs.contains(stageID), !eventID.isEmpty else { return false }
            return GameContent.mysteryEvent(matching: eventID) != nil
                || GameContent.recruitEvent(matching: eventID) != nil
        }
        sanitized.shopPayloads = journey.shopPayloads.filter { stageID, _ in
            validStageIDs.contains(stageID) && !sanitized.completedStageIDs.contains(stageID)
        }
        sanitized.mysteryOfferPayloads = journey.mysteryOfferPayloads.filter { stageID, _ in
            validStageIDs.contains(stageID) && !sanitized.completedStageIDs.contains(stageID)
        }
        if sanitized.pinnedMysteryEventIDs.count != beforePinned {
            sanitizerLogger.info("Sanitized journey: dropped invalid pinned mystery events")
        }

        if !validChapterIDs.contains(sanitized.activeChapterID) {
            sanitized.activeChapterID = activeChapters.first?.id ?? JourneyProgressState.initial.activeChapterID
        }

        if let activeStageID = sanitized.activeStageID,
           validStageIDs.contains(activeStageID),
           !sanitized.completedStageIDs.contains(activeStageID) {
            sanitized.activeStageID = activeStageID
            if let stage = allStages.first(where: { $0.id == activeStageID }) {
                sanitized.activeChapterID = stage.chapterID
            }
        } else if let firstIncomplete = allStages.first(where: {
            $0.chapterID == sanitized.activeChapterID && !sanitized.completedStageIDs.contains($0.id)
        }) ?? allStages.first(where: { !sanitized.completedStageIDs.contains($0.id) }) {
            sanitized.activeStageID = firstIncomplete.id
            sanitized.activeChapterID = firstIncomplete.chapterID
        } else {
            sanitized.activeStageID = nil
            sanitized.activeChapterID = activeChapters.last?.id
                ?? JourneyProgressState.initial.activeChapterID
        }

        return sanitized
    }

    static func sanitizeHomestead(_ homestead: PlayerHomesteadState) -> PlayerHomesteadState {
        var sanitized = homestead
        let beforePending = homestead.pendingProduction.count
        sanitized.pendingProduction = Dictionary(
            uniqueKeysWithValues: homestead.validPendingProduction.map { resource, quantity in
                if resource == .gold {
                    return (resource, PlayerRosterState.cappedPendingGold(quantity))
                }
                return (resource, quantity)
            },
        )
        if sanitized.pendingProduction.count != beforePending {
            sanitizerLogger.info("Sanitized homestead: dropped invalid pending production")
        }
        let hadGoldResource = homestead.resources[.gold] != nil
        sanitized.resources = Dictionary(
            uniqueKeysWithValues: homestead.resources.compactMap { resource, quantity in
                guard resource != .gold else { return nil }
                return (resource, max(0, quantity))
            },
        )
        if hadGoldResource {
            sanitizerLogger.notice("Sanitized homestead: dropped gold from resources (roster owns gold)")
        }
        sanitized.nodeTiers = Dictionary(
            uniqueKeysWithValues: homestead.nodeTiers.compactMap { nodeID, tier in
                guard let maxTier = HomesteadNodeCatalog.maxTierByNodeID[nodeID] else { return nil }
                return (nodeID, min(max(tier, 0), maxTier))
            },
        )
        return sanitized
    }

    static func sanitizeInventory(_ inventory: PlayerInventoryState) -> PlayerInventoryState {
        let uniqueItems = InventoryDuplicatePolicy.deduplicated(inventory.items)
        if uniqueItems.count != inventory.items.count {
            sanitizerLogger
                .notice("Sanitized inventory: dropped \(inventory.items.count - uniqueItems.count, privacy: .public) duplicate items")
        }
        return PlayerInventoryState(items: uniqueItems)
    }

    static func sanitizeRoster(
        _ roster: PlayerRosterState,
        inventory: PlayerInventoryState,
        heroIDs: Set<String> = Set(GameContent.heroes.map(\.id)),
        companionIDs: Set<String> = Set(GameContent.companions.map(\.id)),
    ) -> PlayerRosterState {
        let inventoryItemIDs = Set(inventory.items.map(\.id))
        let validHeroIDs = heroIDs
        let validCompanionIDs = companionIDs

        var sanitized = roster
        sanitized.gold = PlayerRosterState.clampedGoldBalance(roster.gold)
        sanitized.unlockedHeroIDs = roster.unlockedHeroIDs.filtered(to: validHeroIDs)
        sanitized.unlockedCompanionIDs = roster.unlockedCompanionIDs.filtered(to: validCompanionIDs)

        if sanitized.unlockedHeroIDs.isEmpty {
            sanitizerLogger.notice("Sanitized roster: injected starter hero (unlocked set was empty)")
            sanitized.unlockedHeroIDs = [PlayerRosterState.starterHeroID]
        }
        if sanitized.unlockedCompanionIDs.isEmpty {
            sanitizerLogger.notice("Sanitized roster: injected starter companion (unlocked set was empty)")
            sanitized.unlockedCompanionIDs = [PlayerRosterState.starterCompanionID]
        }

        let (resolvedHeroID, resolvedCompanionID) = RosterHydration.resolveActiveSelection(
            activeHeroID: sanitized.activeHeroID,
            activeCompanionID: sanitized.activeCompanionID,
            unlockedHeroIDs: sanitized.unlockedHeroIDs,
            unlockedCompanionIDs: sanitized.unlockedCompanionIDs,
        )
        sanitized.activeHeroID = resolvedHeroID
        sanitized.activeCompanionID = resolvedCompanionID

        sanitized.equipmentLoadouts = RosterHydration.resolveEquipmentLoadouts(
            from: roster.equipmentLoadouts,
            inventoryItemIDs: inventoryItemIDs,
            inventoryItems: inventory.items,
        )

        sanitized.abilityLoadouts = RosterHydration.resolveAbilityLoadouts(
            from: roster.abilityLoadouts,
        )

        sanitized.progressions = sanitizeProgressions(
            roster.progressions,
            validCombatantIDs: validHeroIDs.union(validCompanionIDs),
        )

        sanitized.unlockedTalents = sanitizeUnlockedTalents(
            roster.unlockedTalents,
            validCombatantIDs: validHeroIDs.union(validCompanionIDs),
            progressions: sanitized.progressions,
        )

        return sanitized
    }

    static func sanitizeUnlockedTalents(
        _ talents: [String: Set<String>],
        validCombatantIDs: Set<String>,
        progressions: [String: CombatantProgression] = [:],
    ) -> [String: Set<String>] {
        var sanitized: [String: Set<String>] = [:]
        for (combatantID, nodeIDs) in talents {
            guard validCombatantIDs.contains(combatantID) else { continue }
            let validNodeIDs = CombatantTalentCatalog.validNodeIDs(for: combatantID)
            var filtered = nodeIDs.intersection(validNodeIDs)
            let budget = progressions[combatantID]?.totalTalentPoints ?? 0
            if let config = CombatantTalentCatalog.configIfAvailable(for: combatantID) {
                filtered = config.cappedUnlocks(filtered, budget: budget)
            } else {
                #if DEBUG
                assertionFailure("Missing talent config for \(combatantID) during sanitize")
                #endif
            }
            if !filtered.isEmpty {
                sanitized[combatantID] = filtered
            }
        }
        return sanitized
    }

    static func sanitizeProgressions(
        _ progressions: [String: CombatantProgression],
        validCombatantIDs: Set<String>,
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
                requiredXP: requiredXP,
            )
        }
        return sanitized
    }

    static func sanitizeSpires(
        _ spires: PlayerSpiresState,
        catalog: [SpireDefinition] = GameContent.spires,
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

    static func sanitizeLabyrinth(
        _ labyrinth: PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String] = [],
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> PlayerLabyrinthState {
        LabyrinthSanitizer.sanitize(labyrinth, eligibleRecruitEventIDs: eligibleRecruitEventIDs, eligibleRewards: eligibleRewards)
    }
}

enum LabyrinthSanitizer {
    static func sanitize(
        _ labyrinth: PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String] = [],
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> PlayerLabyrinthState {
        if labyrinth.isMapPayloadUnreadable {
            var healed = labyrinth
            healed.ensureMap(
                seed: labyrinth.worldSeed == 0 ? nil : labyrinth.worldSeed,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs,
                eligibleRewards: eligibleRewards,
            )
            return sanitize(healed, eligibleRecruitEventIDs: eligibleRecruitEventIDs, eligibleRewards: eligibleRewards)
        }

        var sanitized = labyrinth

        sanitized.clusters = sanitized.clusters.map { cluster in
            LabyrinthCluster(
                id: cluster.id,
                depthBand: max(0, cluster.depthBand),
                nodeIDs: cluster.nodeIDs,
            )
        }

        let validClusterIDs = Set(sanitized.clusters.map(\.id))
        sanitized.nodes = sanitized.nodes.filter { _, node in
            validClusterIDs.contains(node.clusterID) || node.id == LabyrinthGenerator.entranceNodeID
        }

        let validNodeIDs = Set(sanitized.nodes.keys)
        let existingNodes = sanitized.nodes
        for (id, node) in existingNodes {
            sanitized.nodes[id] = sanitizedLabyrinthNode(
                node,
                validNodeIDs: validNodeIDs,
                cluster: sanitized.cluster(id: node.clusterID),
                worldSeed: sanitized.worldSeed,
                eligibleRewards: eligibleRewards,
            )
        }

        if sanitized.hasEntered, sanitized.nodes.isEmpty {
            sanitized.ensureMap(
                seed: sanitized.worldSeed == 0 ? nil : sanitized.worldSeed,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs,
                eligibleRewards: eligibleRewards,
            )
        }
        return sanitized
    }

    private static func sanitizedLabyrinthNode(
        _ node: LabyrinthNode,
        validNodeIDs: Set<String>,
        cluster: LabyrinthCluster?,
        worldSeed: UInt64,
        eligibleRewards: [RewardModifier],
    ) -> LabyrinthNode {
        let depth = max(0, node.depth)
        let type: LabyrinthNodeType = if node.type == .entrance, depth > 0 {
            .boss
        } else {
            node.type
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
            gridPosition: node.gridPosition ?? fallbackGridPosition(for: node, in: cluster),
            modifierIDs: LabyrinthCatalog.resolvedModifierIDs(
                for: type,
                enemyID: enemyID,
                existingModifierIDs: node.modifierIDs,
                worldSeed: worldSeed,
                nodeID: node.id,
                eligibleRewards: eligibleRewards,
            ),
            recruitEventID: node.recruitEventID,
            mysteryEventID: node.mysteryEventID,
            mysteryOffersPayload: node.mysteryOffersPayload,
            shopPayload: node.shopPayload,
            outgoingIDs: node.outgoingIDs.filter { validNodeIDs.contains($0) },
            isCleared: node.isCleared,
            isRevealed: depth > 0 || node.isRevealed,
        )
    }

    private static func fallbackGridPosition(
        for node: LabyrinthNode,
        in cluster: LabyrinthCluster?,
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

private func validateEncodedAffixPowers(_ inventory: PlayerInventoryState) throws {
    for item in inventory.items {
        guard let powers = item.affixPowers else { continue }
        do {
            _ = try ItemAffixPowerCoding.encode(powers)
        } catch {
            throw PlayerSavePersistenceError.invalidSave(
                "Inventory item \(item.id) affix powers could not be encoded.",
            )
        }
    }
}

private extension Set<String> {
    /// Single home for ID-allowlist filtering; replaces repeated
    /// `filter { validIDs.contains($0) }` closures.
    func filtered(to validIDs: Set<String>) -> Set<String> {
        filter(validIDs.contains)
    }
}
