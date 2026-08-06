import Foundation
import TrinketContent
import TrinketCore

struct WireAbilityLoadout: Codable, Equatable {
    var basicID: String?
    var skillID: String?
    var ultimateID: String?

    init(_ loadout: AbilityLoadout) {
        basicID = loadout.basic?.id
        skillID = loadout.skill?.id
        ultimateID = loadout.ultimate?.id
    }

    init(basicID: String?, skillID: String?, ultimateID: String?) {
        self.basicID = basicID
        self.skillID = skillID
        self.ultimateID = ultimateID
    }
}

struct WireEquipmentLoadout: Codable, Equatable {
    var itemIDsBySlot: [String: String]

    init(_ loadout: EquipmentLoadout) {
        itemIDsBySlot = Dictionary(uniqueKeysWithValues: loadout.itemIDsBySlot.map { ($0.key.rawValue, $0.value) })
    }

    init(itemIDsBySlot: [String: String]) {
        self.itemIDsBySlot = itemIDsBySlot
    }

    func loadout(inventoryItemIDs: Set<String>) -> EquipmentLoadout {
        var resolved: [ItemSlot: String] = [:]
        for (slotRawValue, itemID) in itemIDsBySlot {
            guard let slot = ItemSlot(rawValue: slotRawValue), inventoryItemIDs.contains(itemID) else { continue }
            resolved[slot] = itemID
        }
        return EquipmentLoadout(itemIDsBySlot: resolved)
    }
}

struct WireItemAffix: Codable, Equatable {
    var id: String
    var title: String
    var description: String
    var keywordRawValues: [String]

    init(_ affix: ItemAffix) {
        id = affix.id
        title = affix.title
        description = affix.description
        keywordRawValues = affix.keywords.map(\.rawValue).sorted()
    }

    init(id: String, title: String, description: String, keywordRawValues: [String]) {
        self.id = id
        self.title = title
        self.description = description
        self.keywordRawValues = keywordRawValues
    }

    func affix() -> ItemAffix? {
        let keywords = Set(keywordRawValues.compactMap { Keyword(rawValue: $0) })
        return ItemAffix(
            id: id,
            title: title,
            description: description,
            keywords: keywords
        )
    }
}

struct WireInventoryItem: Codable, Equatable {
    var id: String
    var templateID: String
    var baseTypeID: String
    var rarity: Rarity
    var displayName: String
    var affixes: [WireItemAffix]
    var isCorrupted: Bool
    var affixPowers: [ItemAffixPowerSnapshot]?

    init(_ item: InventoryItem) {
        id = item.id
        templateID = item.templateID
        baseTypeID = item.baseType.id
        rarity = item.rarity
        displayName = item.displayName
        affixes = item.affixes.map(WireItemAffix.init)
        isCorrupted = item.isCorrupted
        affixPowers = item.affixPowers?.map(ItemAffixPowerSnapshot.init)
    }

    init(
        id: String,
        templateID: String,
        baseTypeID: String,
        rarity: Rarity,
        displayName: String,
        affixes: [WireItemAffix],
        isCorrupted: Bool = false,
        affixPowers: [ItemAffixPowerSnapshot]? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.baseTypeID = baseTypeID
        self.rarity = rarity
        self.displayName = displayName
        self.affixes = affixes
        self.isCorrupted = isCorrupted
        self.affixPowers = affixPowers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        templateID = try container.decode(String.self, forKey: .templateID)
        baseTypeID = try container.decode(String.self, forKey: .baseTypeID)
        rarity = try container.decode(Rarity.self, forKey: .rarity)
        displayName = try container.decode(String.self, forKey: .displayName)
        affixes = try container.decode([WireItemAffix].self, forKey: .affixes)
        isCorrupted = try container.decodeIfPresent(Bool.self, forKey: .isCorrupted) ?? false
        affixPowers = try container.decodeIfPresent([ItemAffixPowerSnapshot].self, forKey: .affixPowers)
    }

    func item() -> InventoryItem? {
        guard let baseType = GameContent.itemBaseTypes.first(where: { $0.id == baseTypeID }) else { return nil }
        let resolvedAffixes = affixes.compactMap { $0.affix() }
        return InventoryItem(
            id: id,
            templateID: templateID,
            baseType: baseType,
            rarity: rarity,
            displayName: displayName,
            affixes: resolvedAffixes,
            isCorrupted: isCorrupted,
            affixPowers: affixPowers?.map { $0.power() }
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case templateID
        case baseTypeID
        case rarity
        case displayName
        case affixes
        case isCorrupted
        case affixPowers
    }
}

struct WireRosterState: Codable, Equatable {
    var activeHeroID: String
    var activeCompanionID: String
    var unlockedHeroIDs: [String]
    var unlockedCompanionIDs: [String]
    var abilityLoadouts: [String: WireAbilityLoadout]
    var progressions: [String: CombatantProgression]
    var equipmentLoadouts: [String: WireEquipmentLoadout]
    var gold: Int
    var primaryStats: [String: PrimaryStats]

    enum CodingKeys: String, CodingKey {
        case activeHeroID
        case activeCompanionID
        case unlockedHeroIDs
        case unlockedCompanionIDs
        case abilityLoadouts
        case progressions
        case equipmentLoadouts
        case gold
        case primaryStats
    }

    init(_ roster: PlayerRosterState) {
        activeHeroID = roster.activeHeroID
        activeCompanionID = roster.activeCompanionID
        unlockedHeroIDs = roster.unlockedHeroIDs.sorted()
        unlockedCompanionIDs = roster.unlockedCompanionIDs.sorted()
        abilityLoadouts = roster.abilityLoadouts.mapValues(WireAbilityLoadout.init)
        progressions = roster.progressions
        equipmentLoadouts = roster.equipmentLoadouts.mapValues(WireEquipmentLoadout.init)
        gold = roster.gold
        primaryStats = roster.primaryStatOverrides
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeHeroID = try container.decode(String.self, forKey: .activeHeroID)
        activeCompanionID = try container.decode(String.self, forKey: .activeCompanionID)
        unlockedHeroIDs = try container.decodeIfPresent([String].self, forKey: .unlockedHeroIDs) ?? []
        unlockedCompanionIDs = try container.decodeIfPresent([String].self, forKey: .unlockedCompanionIDs) ?? []
        abilityLoadouts = try container.decode([String: WireAbilityLoadout].self, forKey: .abilityLoadouts)
        progressions = try container.decode([String: CombatantProgression].self, forKey: .progressions)
        equipmentLoadouts = try container.decode([String: WireEquipmentLoadout].self, forKey: .equipmentLoadouts)
        gold = try container.decode(Int.self, forKey: .gold)
        primaryStats = try container.decodeIfPresent([String: PrimaryStats].self, forKey: .primaryStats) ?? [:]
    }

    func roster(inventory: PlayerInventoryState) -> PlayerRosterState {
        let inventoryItemIDs = Set(inventory.items.map(\.id))
        let unlockedHeroIDSet = Set(unlockedHeroIDs)
        let unlockedCompanionIDSet = Set(unlockedCompanionIDs)
        let (resolvedHeroID, resolvedCompanionID) = RosterHydration.resolveActiveSelection(
            activeHeroID: activeHeroID,
            activeCompanionID: activeCompanionID,
            unlockedHeroIDs: unlockedHeroIDSet,
            unlockedCompanionIDs: unlockedCompanionIDSet
        )

        return PlayerRosterState(
            activeHeroID: resolvedHeroID,
            activeCompanionID: resolvedCompanionID,
            unlockedHeroIDs: unlockedHeroIDSet,
            unlockedCompanionIDs: unlockedCompanionIDSet,
            abilityLoadouts: RosterHydration.resolveAbilityLoadouts(from: abilityLoadouts),
            progressions: progressions,
            equipmentLoadouts: RosterHydration.resolveEquipmentLoadouts(
                from: equipmentLoadouts,
                inventoryItemIDs: inventoryItemIDs,
                inventoryItems: inventory.items
            ),
            gold: gold,
            primaryStatOverrides: primaryStats
        )
    }
}

struct WireInventoryState: Codable, Equatable {
    var items: [WireInventoryItem]

    init(_ inventory: PlayerInventoryState) {
        items = inventory.items.map(WireInventoryItem.init)
    }

    init(items: [WireInventoryItem]) {
        self.items = items
    }

    func inventory() -> PlayerInventoryState {
        PlayerInventoryState(items: items.compactMap { $0.item() })
    }
}

struct WireHomesteadState: Codable, Equatable {
    var resources: [String: Int]
    var nodeTiers: [String: Int]

    init(_ homestead: PlayerHomesteadState) {
        resources = Dictionary(
            uniqueKeysWithValues: homestead.resources.map {
                ($0.key.rawValue, PlayerHomesteadState.clampedMaterialBalance($0.value))
            }
        )
        nodeTiers = Dictionary(
            uniqueKeysWithValues: homestead.nodeTiers.map { ($0.key.rawValue, max($0.value, 0)) }
        )
    }

    init(resources: [String: Int], nodeTiers: [String: Int]) {
        self.resources = resources
        self.nodeTiers = nodeTiers
    }

    func homestead() -> PlayerHomesteadState {
        var resolvedResources: [HomesteadResource: Int] = [:]
        for (rawValue, quantity) in resources {
            guard let resource = HomesteadResource(rawValue: rawValue), resource != .gold else { continue }
            resolvedResources[resource] = PlayerHomesteadState.clampedMaterialBalance(quantity)
        }

        var resolvedNodeTiers: [HomesteadNodeID: Int] = [:]
        for (rawValue, tier) in nodeTiers {
            guard let nodeID = HomesteadNodeID(rawValue: rawValue),
                  let maxTier = HomesteadNodeCatalog.maxTierByNodeID[nodeID]
            else { continue }
            resolvedNodeTiers[nodeID] = min(max(tier, 0), maxTier)
        }

        return PlayerHomesteadState(resources: resolvedResources, nodeTiers: resolvedNodeTiers)
    }
}

struct WireSpiresState: Codable, Equatable {
    var highestClearedFloorBySpireID: [String: Int]

    init(_ spires: PlayerSpiresState) {
        highestClearedFloorBySpireID = spires.highestClearedFloorBySpireID
    }

    init(highestClearedFloorBySpireID: [String: Int]) {
        self.highestClearedFloorBySpireID = highestClearedFloorBySpireID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        highestClearedFloorBySpireID = try container.decodeIfPresent(
            [String: Int].self,
            forKey: .highestClearedFloorBySpireID
        ) ?? container.decodeIfPresent(
            [String: Int].self,
            forKey: .highestClearedFloorByAspectID
        ) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case highestClearedFloorBySpireID
        case highestClearedFloorByAspectID
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(highestClearedFloorBySpireID, forKey: .highestClearedFloorBySpireID)
    }

    func spires() -> PlayerSpiresState {
        PlayerSpiresState(highestClearedFloorBySpireID: highestClearedFloorBySpireID)
    }
}

struct WireLabyrinthState: Codable, Equatable {
    var worldSeed: UInt64
    var mapVersion: Int
    var hasEntered: Bool
    var clusters: [LabyrinthCluster]
    var nodes: [LabyrinthNode]

    init(_ labyrinth: PlayerLabyrinthState) {
        worldSeed = labyrinth.worldSeed
        mapVersion = labyrinth.mapVersion
        hasEntered = labyrinth.hasEntered
        clusters = labyrinth.clusters
        nodes = Array(labyrinth.nodes.values).sorted { $0.id < $1.id }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        worldSeed = try container.decodeIfPresent(UInt64.self, forKey: .worldSeed) ?? 0
        mapVersion = try container.decodeIfPresent(Int.self, forKey: .mapVersion) ?? 1
        hasEntered = try container.decodeIfPresent(Bool.self, forKey: .hasEntered) ?? false
        clusters = try container.decodeIfPresent([LabyrinthCluster].self, forKey: .clusters) ?? []
        nodes = try container.decodeIfPresent([LabyrinthNode].self, forKey: .nodes) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case worldSeed
        case mapVersion
        case hasEntered
        case clusters
        case nodes
    }

    func labyrinth() -> PlayerLabyrinthState {
        PlayerLabyrinthState(
            worldSeed: worldSeed,
            mapVersion: mapVersion,
            hasEntered: hasEntered,
            clusters: clusters,
            nodes: Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        )
    }
}
