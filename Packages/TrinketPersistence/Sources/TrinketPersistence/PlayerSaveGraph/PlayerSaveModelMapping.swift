import Foundation
import os
import SwiftData
import TrinketContent
import TrinketCore

private let labyrinthMapLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "LabyrinthMapPayload",
)

let inventoryMappingLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "InventoryMapping",
)
private struct UnlockedCombatantValue {
    static let heroRole = "hero"
    static let companionRole = "companion"

    let combatantID: String
    let role: String

    var key: String {
        "\(role):\(combatantID)"
    }
}

private struct EquipmentLoadoutValue {
    let combatantID: String
    let loadout: EquipmentLoadout
}

extension RosterModel {
    private func updateEquipmentLoadout(
        _ model: EquipmentLoadoutModel,
        from value: EquipmentLoadoutValue,
        context: ModelContext?,
    ) {
        model.combatantID = value.combatantID
        let slots = value.loadout.itemIDsBySlot
            .map { (slotID: $0.key.rawValue, itemID: $0.value) }
            .sorted { $0.slotID < $1.slotID }
        model.slots = reconcileModels(
            existing: model.slots ?? [],
            values: slots,
            existingKey: \.slotID,
            valueKey: { $0.slotID },
            make: { EquipmentSlotModel(slotID: $0.slotID, itemID: $0.itemID) },
            update: { slotModel, slot in
                slotModel.slotID = slot.slotID
                slotModel.itemID = slot.itemID
            },
            link: { $0.loadout = model },
            context: context,
        )
    }
}

extension InventoryItemModel {
    func update(from item: InventoryItem, context: ModelContext?) {
        id = item.id
        templateID = item.templateID
        baseTypeID = item.baseType.id
        rarityID = item.rarity.rawValue
        displayName = item.displayName
        isCorrupted = item.isCorrupted
        applyAffixPowers(from: item)
        let values = item.affixes.enumerated().map { (index: $0.offset, affix: $0.element) }
        affixes = reconcileModels(
            existing: affixes ?? [],
            values: values,
            existingKey: \.id,
            valueKey: { $0.affix.id },
            make: { ItemAffixModel(affix: $0.affix) },
            update: { model, value in
                model.id = value.affix.id
                model.title = value.affix.title
                model.affixDescription = value.affix.description
                model.keywordRawValues = value.affix.keywords.map(\.rawValue).sorted()
                model.isCorrupted = value.affix.isCorrupted
                model.sortIndex = value.index
            },
            link: { $0.item = self },
            context: context,
        )
    }
}

extension RosterModel {
    func update(from roster: PlayerRosterState, context: ModelContext?) {
        activeHeroID = roster.activeHeroID
        activeCompanionID = roster.activeCompanionID
        gold = roster.gold
        updateUnlockedCombatants(from: roster, context: context)
        updateProgressions(from: roster, context: context)
        updateAbilityLoadouts(from: roster, context: context)
        updateTalentLoadouts(from: roster, context: context)
        updateEquipmentLoadouts(from: roster, context: context)
    }

    private func updateUnlockedCombatants(from roster: PlayerRosterState, context: ModelContext?) {
        let unlockedValues = roster.unlockedHeroIDs.sorted().map {
            UnlockedCombatantValue(combatantID: $0, role: UnlockedCombatantValue.heroRole)
        } + roster.unlockedCompanionIDs.sorted().map {
            UnlockedCombatantValue(combatantID: $0, role: UnlockedCombatantValue.companionRole)
        }
        unlockedCombatants = reconcileModels(
            existing: unlockedCombatants ?? [],
            values: unlockedValues,
            existingKey: \UnlockedCombatantModel.compositeKey,
            valueKey: { $0.key },
            make: { UnlockedCombatantModel(combatantID: $0.combatantID, role: $0.role) },
            update: { model, value in
                model.combatantID = value.combatantID
                model.role = value.role
            },
            link: { $0.roster = self },
            context: context,
        )
    }

    private func updateProgressions(from roster: PlayerRosterState, context: ModelContext?) {
        let progressionValues = roster.progressions.sorted { $0.key < $1.key }
        progressions = reconcileModels(
            existing: progressions ?? [],
            values: progressionValues,
            existingKey: \.combatantID,
            valueKey: { $0.key },
            make: { CombatantProgressionModel(combatantID: $0.key, progression: $0.value) },
            update: { model, value in
                model.combatantID = value.key
                model.level = value.value.level
                model.currentXP = value.value.currentXP
                model.requiredXP = value.value.requiredXP
            },
            link: { $0.roster = self },
            context: context,
        )
    }

    private func updateAbilityLoadouts(from roster: PlayerRosterState, context: ModelContext?) {
        let abilityValues = roster.abilityLoadouts.sorted { $0.key < $1.key }
        abilityLoadouts = reconcileModels(
            existing: abilityLoadouts ?? [],
            values: abilityValues,
            existingKey: \.combatantID,
            valueKey: { $0.key },
            make: { AbilityLoadoutModel(combatantID: $0.key, loadout: $0.value) },
            update: { model, value in
                model.combatantID = value.key
                model.basicID = value.value.basic?.id
                model.skillID = value.value.skill?.id
                model.ultimateID = value.value.ultimate?.id
            },
            link: { $0.roster = self },
            context: context,
        )
    }

    private func updateTalentLoadouts(from roster: PlayerRosterState, context: ModelContext?) {
        let talentValues = roster.unlockedTalents
            .map { (combatantID: $0.key, nodeIDs: Array($0.value).sorted()) }
            .sorted { $0.combatantID < $1.combatantID }
        talentLoadouts = reconcileModels(
            existing: talentLoadouts ?? [],
            values: talentValues,
            existingKey: \.combatantID,
            valueKey: { $0.combatantID },
            make: { TalentLoadoutModel(combatantID: $0.combatantID) },
            update: { model, value in
                self.updateTalentLoadout(model, from: value, context: context)
            },
            link: { $0.roster = self },
            context: context,
        )
    }

    private func updateTalentLoadout(
        _ model: TalentLoadoutModel,
        from value: (combatantID: String, nodeIDs: [String]),
        context: ModelContext?,
    ) {
        model.combatantID = value.combatantID
        model.unlockedNodes = reconcileModels(
            existing: model.unlockedNodes ?? [],
            values: value.nodeIDs,
            existingKey: \.nodeID,
            valueKey: { $0 },
            make: { TalentNodeUnlockModel(nodeID: $0) },
            update: { unlockModel, nodeID in
                unlockModel.nodeID = nodeID
            },
            link: { $0.loadout = model },
            context: context,
        )
    }

    private func updateEquipmentLoadouts(from roster: PlayerRosterState, context: ModelContext?) {
        let equipmentValues = roster.equipmentLoadouts
            .map { EquipmentLoadoutValue(combatantID: $0.key, loadout: $0.value) }
            .sorted { $0.combatantID < $1.combatantID }
        equipmentLoadouts = reconcileModels(
            existing: equipmentLoadouts ?? [],
            values: equipmentValues,
            existingKey: \.combatantID,
            valueKey: { $0.combatantID },
            make: { EquipmentLoadoutModel(combatantID: $0.combatantID) },
            update: { model, value in
                self.updateEquipmentLoadout(model, from: value, context: context)
            },
            link: { $0.roster = self },
            context: context,
        )
    }
}

extension RosterModel {
    func toPlayerRosterState(
        schemaVersion: Int = PlayerSave.currentSchemaVersion,
    ) -> PlayerRosterState {
        let unlocked = unlockedCombatants ?? []
        let heroIDs = Set(unlocked.filter { $0.role == UnlockedCombatantValue.heroRole }.map(\.combatantID))
        let companionIDs = Set(unlocked.filter { $0.role == UnlockedCombatantValue.companionRole }.map(\.combatantID))
        let progressionValues = Dictionary(
            (progressions ?? []).map {
                ($0.combatantID, CombatantProgression(level: $0.level, currentXP: $0.currentXP, requiredXP: $0.requiredXP))
            },
            uniquingKeysWith: { _, new in new },
        )
        let abilityIDValues = Dictionary(
            (abilityLoadouts ?? []).map {
                ($0.combatantID, RosterHydration.AbilityLoadoutIDs(basicID: $0.basicID, skillID: $0.skillID, ultimateID: $0.ultimateID))
            },
            uniquingKeysWith: { _, new in new },
        )
        let equipmentValues = Dictionary(
            (equipmentLoadouts ?? []).map { loadoutModel in
                let isHero = GameContent.combatant(matching: loadoutModel.combatantID)?.role == .hero
                return (
                    loadoutModel.combatantID,
                    EquipmentLoadout(itemIDsBySlot: Dictionary(
                        (loadoutModel.slots ?? []).compactMap { slot in
                            let resolvedSlot = RosterHydration.resolveEquipmentSlot(
                                slot.slotID,
                                schemaVersion: schemaVersion,
                                isHero: isHero,
                            )
                            return resolvedSlot.map { ($0, slot.itemID) }
                        },
                        uniquingKeysWith: { _, new in new },
                    )),
                )
            },
            uniquingKeysWith: { _, new in new },
        )
        let talentValues = Dictionary(
            (talentLoadouts ?? []).map { loadoutModel in
                (loadoutModel.combatantID, Set((loadoutModel.unlockedNodes ?? []).map(\.nodeID)))
            },
            uniquingKeysWith: { _, new in new },
        )

        return PlayerRosterState(
            activeHeroID: activeHeroID,
            activeCompanionID: activeCompanionID,
            unlockedHeroIDs: heroIDs,
            unlockedCompanionIDs: companionIDs,
            abilityLoadouts: RosterHydration.rawAbilityLoadouts(from: abilityIDValues),
            progressions: progressionValues,
            equipmentLoadouts: equipmentValues,
            unlockedTalents: talentValues,
            gold: gold,
        )
    }
}

extension InventoryModel {
    func update(from inventory: PlayerInventoryState, context: ModelContext?) {
        let values = inventory.items.enumerated().map { (index: $0.offset, item: $0.element) }
        items = reconcileModels(
            existing: items ?? [],
            values: values,
            existingKey: \.id,
            valueKey: { $0.item.id },
            make: { _ in InventoryItemModel() },
            update: { model, value in
                model.update(from: value.item, context: context)
                model.sortIndex = value.index
            },
            link: { $0.inventory = self },
            context: context,
        )
    }
}

extension HomesteadModel {
    func toPlayerHomesteadState() -> PlayerHomesteadState {
        var resolvedResources: [HomesteadResource: Int] = [:]
        for balance in resources ?? [] {
            guard let resource = HomesteadResource(rawValue: balance.resourceID), resource != .gold else { continue }
            resolvedResources[resource] = balance.quantity
        }
        var resolvedPendingProduction: [HomesteadResource: Double] = [:]
        for pending in pendingProduction ?? [] {
            guard let resource = HomesteadResource(rawValue: pending.resourceID) else { continue }
            resolvedPendingProduction[resource] = pending.quantity
        }
        var resolvedNodeTiers: [HomesteadNodeID: Int] = [:]
        for tierModel in nodeTiers ?? [] {
            guard let nodeID = HomesteadNodeID(rawValue: tierModel.nodeID) else { continue }
            resolvedNodeTiers[nodeID] = tierModel.tier
        }
        return PlayerHomesteadState(
            resources: resolvedResources,
            nodeTiers: resolvedNodeTiers,
            pendingProduction: resolvedPendingProduction,
            lastProductionAt: lastProductionAt,
        )
    }

    func update(from homestead: PlayerHomesteadState, context: ModelContext?) {
        lastProductionAt = homestead.lastProductionAt

        let resourceValues = homestead.resources
            .map { (resourceID: $0.key.rawValue, quantity: $0.value) }
            .sorted { $0.resourceID < $1.resourceID }
        resources = reconcileModels(
            existing: resources ?? [],
            values: resourceValues,
            existingKey: \.resourceID,
            valueKey: { $0.resourceID },
            make: { HomesteadResourceBalanceModel(resourceID: $0.resourceID, quantity: $0.quantity) },
            update: { model, value in
                model.resourceID = value.resourceID
                model.quantity = value.quantity
            },
            link: { $0.homestead = self },
            context: context,
        )

        let pendingValues = homestead.pendingProduction
            .filter { $0.value.isFinite && $0.value > 0 }
            .map { (resourceID: $0.key.rawValue, quantity: $0.value) }
            .sorted { $0.resourceID < $1.resourceID }
        pendingProduction = reconcileModels(
            existing: pendingProduction ?? [],
            values: pendingValues,
            existingKey: \.resourceID,
            valueKey: { $0.resourceID },
            make: { HomesteadPendingProductionModel(resourceID: $0.resourceID, quantity: $0.quantity) },
            update: { model, value in
                model.resourceID = value.resourceID
                model.quantity = value.quantity
            },
            link: { $0.homestead = self },
            context: context,
        )

        let tierValues = homestead.nodeTiers
            .map { (nodeID: $0.key.rawValue, tier: $0.value) }
            .sorted { $0.nodeID < $1.nodeID }
        nodeTiers = reconcileModels(
            existing: nodeTiers ?? [],
            values: tierValues,
            existingKey: \.nodeID,
            valueKey: { $0.nodeID },
            make: { HomesteadNodeTierModel(nodeID: $0.nodeID, tier: $0.tier) },
            update: { model, value in
                model.nodeID = value.nodeID
                model.tier = value.tier
            },
            link: { $0.homestead = self },
            context: context,
        )
    }
}

extension SpiresProgressModel {
    func toPlayerSpiresState() -> PlayerSpiresState {
        let rows = floors ?? []
        var map: [String: Int] = [:]
        for row in rows where !row.spireID.isEmpty {
            map[row.spireID] = row.highestClearedFloor
        }
        return PlayerSpiresState(highestClearedFloorBySpireID: map)
    }

    func update(from state: PlayerSpiresState, context: ModelContext?) {
        let values = state.highestClearedFloorBySpireID.sorted { $0.key < $1.key }
        floors = reconcileModels(
            existing: floors ?? [],
            values: values,
            existingKey: \.spireID,
            valueKey: { $0.key },
            make: { SpireFloorProgressModel(spireID: $0.key, highestClearedFloor: max(0, $0.value)) },
            update: { model, value in
                model.spireID = value.key
                model.highestClearedFloor = max(0, value.value)
            },
            link: { $0.spires = self },
            context: context,
        )
    }
}

extension LabyrinthProgressModel {
    func toPlayerLabyrinthState() -> PlayerLabyrinthState {
        switch decodeMapPayload() {
        case .missing:
            PlayerLabyrinthState(
                worldSeed: worldSeed,
                mapVersion: mapVersion,
                hasEntered: hasEntered,
                clusters: [],
                nodes: [:],
            )
        case let .decoded(payload):
            PlayerLabyrinthState(
                worldSeed: worldSeed,
                mapVersion: mapVersion,
                hasEntered: hasEntered,
                clusters: payload.clusters,
                nodes: Dictionary(
                    payload.nodes.map { ($0.id, $0) },
                    uniquingKeysWith: { _, new in new },
                ),
                runHealthByCombatantID: payload.runHealthByCombatantID,
            )
        case .unreadable:
            PlayerLabyrinthState(
                worldSeed: worldSeed,
                mapVersion: mapVersion,
                hasEntered: hasEntered,
                clusters: [],
                nodes: [:],
                isMapPayloadUnreadable: true,
            )
        }
    }

    func update(from state: PlayerLabyrinthState) {
        worldSeed = state.worldSeed
        mapVersion = state.mapVersion
        hasEntered = state.hasEntered
        if state.isMapPayloadUnreadable {
            return
        }
        let payload = LabyrinthMapPayload(
            clusters: state.clusters,
            nodes: Array(state.nodes.values).sorted { $0.id < $1.id },
            runHealthByCombatantID: state.runHealthByCombatantID,
        )
        do {
            mapPayload = try JSONEncoder().encode(payload)
        } catch {
            labyrinthMapLogger.error(
                "Failed to encode labyrinth map payload: \(error.localizedDescription, privacy: .public)",
            )
        }
    }

    private enum MapPayloadDecode {
        case missing
        case decoded(LabyrinthMapPayload)
        case unreadable
    }

    private func decodeMapPayload() -> MapPayloadDecode {
        guard let mapPayload else {
            return .missing
        }
        do {
            return try .decoded(JSONDecoder().decode(LabyrinthMapPayload.self, from: mapPayload))
        } catch {
            labyrinthMapLogger.error(
                "Failed to decode labyrinth map payload; keeping stored blob: \(error.localizedDescription, privacy: .public)",
            )
            return .unreadable
        }
    }
}

func reconcileModels<Model: PersistentModel, Value, Key: Hashable>(
    existing: [Model],
    values: [Value],
    existingKey: (Model) -> Key,
    valueKey: (Value) -> Key,
    make: (Value) -> Model,
    update: (Model, Value) -> Void,
    link: ((Model) -> Void)? = nil,
    context: ModelContext?,
) -> [Model] {
    var modelsByKey = [Key: Model](minimumCapacity: existing.count)
    for model in existing {
        let key = existingKey(model)
        if modelsByKey[key] == nil {
            modelsByKey[key] = model
        } else {
            context?.delete(model)
        }
    }

    var reconciled: [Model] = []
    reconciled.reserveCapacity(values.count)
    for value in values {
        if let model = modelsByKey.removeValue(forKey: valueKey(value)) {
            update(model, value)
            reconciled.append(model)
        } else {
            let model = make(value)
            update(model, value)
            link?(model)
            reconciled.append(model)
        }
    }
    for removed in modelsByKey.values {
        context?.delete(removed)
    }
    return reconciled
}
