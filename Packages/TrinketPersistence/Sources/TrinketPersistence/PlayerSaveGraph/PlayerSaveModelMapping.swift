import Foundation
import TrinketContent
import TrinketCore

extension JourneyProgressModel {
    func toJourneyProgressState() -> JourneyProgressState {
        let stageModels = stages ?? []
        return JourneyProgressState(
            activeChapterID: activeChapterID,
            activeStageID: activeStageID,
            completedStageIDs: Set(stageModels.filter(\.isCompleted).map(\.stageID)),
            claimedRewardStageIDs: Set(stageModels.filter(\.rewardsClaimed).map(\.stageID)),
            lastCompletedStageID: lastCompletedStageID
        )
    }

    func update(from state: JourneyProgressState) {
        activeChapterID = state.activeChapterID
        activeStageID = state.activeStageID
        lastCompletedStageID = state.lastCompletedStageID
        let allStageIDs = state.completedStageIDs.union(state.claimedRewardStageIDs)
        stages = allStageIDs.sorted().map {
            JourneyStageProgressModel(
                stageID: $0,
                isCompleted: state.completedStageIDs.contains($0),
                rewardsClaimed: state.claimedRewardStageIDs.contains($0)
            )
        }
        stages?.linkEach(to: self, parent: \.journey)
    }
}

extension RosterModel {
    func toPlayerRosterState(inventory: PlayerInventoryState) -> PlayerRosterState {
        let unlocked = unlockedCombatants ?? []
        let heroIDs = Set(unlocked.filter { $0.role == "hero" }.map(\.combatantID))
        let petIDs = Set(unlocked.filter { $0.role == "pet" }.map(\.combatantID))
        let progressionValues = Dictionary(
            uniqueKeysWithValues: (progressions ?? []).map {
                ($0.combatantID, CombatantProgression(level: $0.level, currentXP: $0.currentXP, requiredXP: $0.requiredXP))
            }
        )
        let wireAbilityValues = Dictionary(
            uniqueKeysWithValues: (abilityLoadouts ?? []).map {
                ($0.combatantID, WireAbilityLoadout(basicID: $0.basicID, skillID: $0.skillID, ultimateID: $0.ultimateID))
            }
        )
        let wireEquipmentValues = Dictionary(
            uniqueKeysWithValues: (equipmentLoadouts ?? []).map {
                ($0.combatantID, WireEquipmentLoadout(itemIDsBySlot: Dictionary(uniqueKeysWithValues: ($0.slots ?? []).map { ($0.slotID, $0.itemID) })))
            }
        )
        let statValues = Dictionary(
            uniqueKeysWithValues: (primaryStats ?? []).map {
                (
                    $0.combatantID,
                    PrimaryStats(
                        strength: $0.strength,
                        agility: $0.agility,
                        toughness: $0.toughness,
                        intellect: $0.intellect,
                        wisdom: $0.wisdom
                    )
                )
            }
        )
        let inventoryItemIDs = Set(inventory.items.map(\.id))
        let (resolvedHeroID, resolvedPetID) = RosterHydration.resolveActiveSelection(
            activeHeroID: activeHeroID,
            activePetID: activePetID,
            unlockedHeroIDs: heroIDs,
            unlockedPetIDs: petIDs
        )

        return PlayerRosterState(
            activeHeroID: resolvedHeroID,
            activePetID: resolvedPetID,
            unlockedHeroIDs: heroIDs,
            unlockedPetIDs: petIDs,
            abilityLoadouts: RosterHydration.resolveAbilityLoadouts(from: wireAbilityValues),
            progressions: progressionValues,
            equipmentLoadouts: RosterHydration.resolveEquipmentLoadouts(
                from: wireEquipmentValues,
                inventoryItemIDs: inventoryItemIDs,
                inventoryItems: inventory.items
            ),
            gold: gold,
            primaryStatOverrides: statValues
        )
    }

    func update(from roster: PlayerRosterState) {
        activeHeroID = roster.activeHeroID
        activePetID = roster.activePetID
        gold = roster.gold

        unlockedCombatants = roster.unlockedHeroIDs.sorted().map { UnlockedCombatantModel(combatantID: $0, role: "hero") }
            + roster.unlockedPetIDs.sorted().map { UnlockedCombatantModel(combatantID: $0, role: "pet") }
        unlockedCombatants?.linkEach(to: self, parent: \.roster)

        progressions = roster.progressions
            .sorted { $0.key < $1.key }
            .map { CombatantProgressionModel(combatantID: $0.key, progression: $0.value) }
        progressions?.linkEach(to: self, parent: \.roster)

        abilityLoadouts = roster.abilityLoadouts
            .sorted { $0.key < $1.key }
            .map { AbilityLoadoutModel(combatantID: $0.key, loadout: $0.value) }
        abilityLoadouts?.linkEach(to: self, parent: \.roster)

        equipmentLoadouts = roster.equipmentLoadouts
            .sorted { $0.key < $1.key }
            .map { combatantID, loadout in
                let model = EquipmentLoadoutModel(combatantID: combatantID)
                model.slots = loadout.itemIDsBySlot
                    .map { EquipmentSlotModel(slotID: $0.key.rawValue, itemID: $0.value) }
                    .sorted { $0.slotID < $1.slotID }
                model.slots?.linkEach(to: model, parent: \.loadout)
                return model
            }
        equipmentLoadouts?.linkEach(to: self, parent: \.roster)

        primaryStats = roster.primaryStatOverrides
            .sorted { $0.key < $1.key }
            .map { PrimaryStatsModel(combatantID: $0.key, stats: $0.value) }
        primaryStats?.linkEach(to: self, parent: \.roster)
    }
}

extension InventoryModel {
    func toPlayerInventoryState() -> PlayerInventoryState {
        PlayerInventoryState(items: (items ?? [])
            .sorted { lhs, rhs in
                if lhs.sortIndex == rhs.sortIndex { return lhs.id < rhs.id }
                return lhs.sortIndex < rhs.sortIndex
            }
            .compactMap { item in
                guard let baseType = GameContent.itemBaseTypes.first(where: { $0.id == item.baseTypeID }) else {
                    return nil
                }
                let affixes = (item.affixes ?? [])
                    .sorted { lhs, rhs in
                        if lhs.sortIndex == rhs.sortIndex { return lhs.id < rhs.id }
                        return lhs.sortIndex < rhs.sortIndex
                    }
                    .compactMap { affix in
                        let keywords = Set(affix.keywordRawValues.compactMap { Keyword(rawValue: $0) })
                        return ItemAffix(
                            id: affix.id,
                            title: affix.title,
                            description: affix.affixDescription,
                            keywords: keywords
                        )
                    }
                return InventoryItem(
                    id: item.id,
                    templateID: item.templateID,
                    baseType: baseType,
                    rarity: Rarity(rawValue: item.rarityID) ?? .basic,
                    displayName: item.displayName,
                    affixes: affixes
                )
            })
    }

    func update(from inventory: PlayerInventoryState) {
        items = inventory.items.enumerated().map { index, item in
            let model = InventoryItemModel(item: item)
            model.sortIndex = index
            return model
        }
        items?.forEach { item in
            item.inventory = self
            item.affixes?.linkEach(to: item, parent: \.item)
        }
    }
}

extension HomesteadModel {
    func toPlayerHomesteadState() -> PlayerHomesteadState {
        var resolvedResources: [HomesteadResource: Int] = [:]
        for balance in resources ?? [] {
            guard let resource = HomesteadResource(rawValue: balance.resourceID), resource != .gold else { continue }
            resolvedResources[resource] = max(balance.quantity, 0)
        }
        var resolvedNodeTiers: [HomesteadNodeID: Int] = [:]
        for tierModel in nodeTiers ?? [] {
            guard let nodeID = HomesteadNodeID(rawValue: tierModel.nodeID),
                  let maxTier = HomesteadNodeCatalog.maxTierByNodeID[nodeID]
            else { continue }
            resolvedNodeTiers[nodeID] = min(max(tierModel.tier, 0), maxTier)
        }
        return PlayerHomesteadState(resources: resolvedResources, nodeTiers: resolvedNodeTiers)
    }

    func update(from homestead: PlayerHomesteadState) {
        resources = homestead.resources
            .map { HomesteadResourceBalanceModel(resourceID: $0.key.rawValue, quantity: $0.value) }
            .sorted { $0.resourceID < $1.resourceID }
        resources?.linkEach(to: self, parent: \.homestead)
        nodeTiers = homestead.nodeTiers
            .map { HomesteadNodeTierModel(nodeID: $0.key.rawValue, tier: $0.value) }
            .sorted { $0.nodeID < $1.nodeID }
        nodeTiers?.linkEach(to: self, parent: \.homestead)
    }
}

extension AspectsProgressModel {
    func toPlayerAspectsState() -> PlayerAspectsState {
        let rows = floors ?? []
        var map: [String: Int] = [:]
        for row in rows where !row.aspectID.isEmpty {
            map[row.aspectID] = max(0, row.highestClearedFloor)
        }
        return PlayerAspectsState(highestClearedFloorByAspectID: map)
    }

    func update(from state: PlayerAspectsState) {
        let existing = floors ?? []
        for row in existing {
            row.aspects = nil
        }
        floors = state.highestClearedFloorByAspectID
            .sorted { $0.key < $1.key }
            .map { AspectFloorProgressModel(aspectID: $0.key, highestClearedFloor: max(0, $0.value)) }
        floors?.linkEach(to: self, parent: \.aspects)
    }
}

extension LabyrinthProgressModel {
    func toPlayerLabyrinthState() -> PlayerLabyrinthState {
        let payload = decodeMapPayload()
        return PlayerLabyrinthState(
            worldSeed: worldSeed,
            deepestDepth: max(0, deepestDepth),
            hasEntered: hasEntered,
            clusters: payload.clusters,
            nodes: Dictionary(uniqueKeysWithValues: payload.nodes.map { ($0.id, $0) }),
            discoveredBiomeIDs: Set(discoveredBiomeIDs),
            discoveredModifierIDs: Set(discoveredModifierIDs),
            claimedMilestoneDepths: Set(claimedMilestoneDepths)
        )
    }

    func update(from state: PlayerLabyrinthState) {
        worldSeed = state.worldSeed
        deepestDepth = max(0, state.deepestDepth)
        hasEntered = state.hasEntered
        discoveredBiomeIDs = state.discoveredBiomeIDs.sorted()
        discoveredModifierIDs = state.discoveredModifierIDs.sorted()
        claimedMilestoneDepths = state.claimedMilestoneDepths.sorted()
        let payload = LabyrinthMapPayload(
            clusters: state.clusters,
            nodes: Array(state.nodes.values).sorted { $0.id < $1.id }
        )
        mapPayload = try? JSONEncoder().encode(payload)
    }

    private func decodeMapPayload() -> LabyrinthMapPayload {
        guard let mapPayload,
              let decoded = try? JSONDecoder().decode(LabyrinthMapPayload.self, from: mapPayload)
        else {
            return LabyrinthMapPayload(clusters: [], nodes: [])
        }
        return decoded
    }
}

extension Array {
    func linkEach<Parent>(
        to parent: Parent,
        parent keyPath: ReferenceWritableKeyPath<Element, Parent?>
    ) {
        forEach { $0[keyPath: keyPath] = parent }
    }
}
