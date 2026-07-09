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

    func loadout(defaults: AbilityLoadout, choices: AbilityChoices) -> AbilityLoadout {
        func resolved(_ id: String?, tier: AbilityTier, fallback: Ability?) -> Ability? {
            guard let id else { return fallback }
            return choices.abilities(for: tier).first { $0.id == id } ?? fallback
        }

        return AbilityLoadout(
            basic: resolved(basicID, tier: .basic, fallback: defaults.basic),
            skill: resolved(skillID, tier: .skill, fallback: defaults.skill),
            ultimate: resolved(ultimateID, tier: .ultimate, fallback: defaults.ultimate)
        )
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        keywordRawValues = try container.decode([String].self, forKey: .keywordRawValues)
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

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case keywordRawValues
    }
}

struct WireInventoryItem: Codable, Equatable {
    var id: String
    var templateID: String
    var baseTypeID: String
    var rarity: Rarity
    var displayName: String
    var affixes: [WireItemAffix]

    init(_ item: InventoryItem) {
        id = item.id
        templateID = item.templateID
        baseTypeID = item.baseType.id
        rarity = item.rarity
        displayName = item.displayName
        affixes = item.affixes.map(WireItemAffix.init)
    }

    init(
        id: String,
        templateID: String,
        baseTypeID: String,
        rarity: Rarity,
        displayName: String,
        affixes: [WireItemAffix]
    ) {
        self.id = id
        self.templateID = templateID
        self.baseTypeID = baseTypeID
        self.rarity = rarity
        self.displayName = displayName
        self.affixes = affixes
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
            affixes: resolvedAffixes
        )
    }
}

struct WireRosterState: Codable, Equatable {
    var activeHeroID: String
    var activePetID: String
    var unlockedHeroIDs: [String]
    var unlockedPetIDs: [String]
    var abilityLoadouts: [String: WireAbilityLoadout]
    var progressions: [String: CombatantProgression]
    var equipmentLoadouts: [String: WireEquipmentLoadout]
    var gold: Int
    var primaryStats: [String: PrimaryStats]

    enum CodingKeys: String, CodingKey {
        case activeHeroID
        case activePetID
        case unlockedHeroIDs
        case unlockedPetIDs
        case abilityLoadouts
        case progressions
        case equipmentLoadouts
        case gold
        case primaryStats
    }

    init(_ roster: PlayerRosterState) {
        activeHeroID = roster.activeHeroID
        activePetID = roster.activePetID
        unlockedHeroIDs = roster.unlockedHeroIDs.sorted()
        unlockedPetIDs = roster.unlockedPetIDs.sorted()
        abilityLoadouts = roster.abilityLoadouts.mapValues(WireAbilityLoadout.init)
        progressions = roster.progressions
        equipmentLoadouts = roster.equipmentLoadouts.mapValues(WireEquipmentLoadout.init)
        gold = roster.gold
        primaryStats = roster.primaryStatOverrides
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeHeroID = try container.decode(String.self, forKey: .activeHeroID)
        activePetID = try container.decode(String.self, forKey: .activePetID)
        unlockedHeroIDs = try container.decodeIfPresent([String].self, forKey: .unlockedHeroIDs) ?? []
        unlockedPetIDs = try container.decodeIfPresent([String].self, forKey: .unlockedPetIDs) ?? []
        abilityLoadouts = try container.decode([String: WireAbilityLoadout].self, forKey: .abilityLoadouts)
        progressions = try container.decode([String: CombatantProgression].self, forKey: .progressions)
        equipmentLoadouts = try container.decode([String: WireEquipmentLoadout].self, forKey: .equipmentLoadouts)
        gold = try container.decode(Int.self, forKey: .gold)
        primaryStats = try container.decodeIfPresent([String: PrimaryStats].self, forKey: .primaryStats) ?? [:]
    }

    func roster(inventory: PlayerInventoryState) -> PlayerRosterState {
        let inventoryItemIDs = Set(inventory.items.map(\.id))
        let unlockedHeroIDSet = Set(unlockedHeroIDs)
        let unlockedPetIDSet = Set(unlockedPetIDs)
        let (resolvedHeroID, resolvedPetID) = RosterHydration.resolveActiveSelection(
            activeHeroID: activeHeroID,
            activePetID: activePetID,
            unlockedHeroIDs: unlockedHeroIDSet,
            unlockedPetIDs: unlockedPetIDSet
        )

        return PlayerRosterState(
            activeHeroID: resolvedHeroID,
            activePetID: resolvedPetID,
            unlockedHeroIDs: unlockedHeroIDSet,
            unlockedPetIDs: unlockedPetIDSet,
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
            uniqueKeysWithValues: homestead.resources.map { ($0.key.rawValue, max($0.value, 0)) }
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
            resolvedResources[resource] = max(quantity, 0)
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

struct WireAspectsState: Codable, Equatable {
    var highestClearedFloorByAspectID: [String: Int]

    init(_ aspects: PlayerAspectsState) {
        highestClearedFloorByAspectID = aspects.highestClearedFloorByAspectID
    }

    init(highestClearedFloorByAspectID: [String: Int]) {
        self.highestClearedFloorByAspectID = highestClearedFloorByAspectID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        highestClearedFloorByAspectID = try container.decodeIfPresent(
            [String: Int].self,
            forKey: .highestClearedFloorByAspectID
        ) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case highestClearedFloorByAspectID
    }

    func aspects() -> PlayerAspectsState {
        PlayerAspectsState(highestClearedFloorByAspectID: highestClearedFloorByAspectID)
    }
}

struct WireLabyrinthState: Codable, Equatable {
    var worldSeed: UInt64
    var deepestDepth: Int
    var hasEntered: Bool
    var clusters: [LabyrinthCluster]
    var nodes: [LabyrinthNode]
    var discoveredBiomeIDs: [String]
    var discoveredModifierIDs: [String]
    var claimedMilestoneDepths: [Int]

    init(_ labyrinth: PlayerLabyrinthState) {
        worldSeed = labyrinth.worldSeed
        deepestDepth = labyrinth.deepestDepth
        hasEntered = labyrinth.hasEntered
        clusters = labyrinth.clusters
        nodes = Array(labyrinth.nodes.values).sorted { $0.id < $1.id }
        discoveredBiomeIDs = labyrinth.discoveredBiomeIDs.sorted()
        discoveredModifierIDs = labyrinth.discoveredModifierIDs.sorted()
        claimedMilestoneDepths = labyrinth.claimedMilestoneDepths.sorted()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        worldSeed = try container.decodeIfPresent(UInt64.self, forKey: .worldSeed) ?? 0
        deepestDepth = try container.decodeIfPresent(Int.self, forKey: .deepestDepth) ?? 0
        hasEntered = try container.decodeIfPresent(Bool.self, forKey: .hasEntered) ?? false
        clusters = try container.decodeIfPresent([LabyrinthCluster].self, forKey: .clusters) ?? []
        nodes = try container.decodeIfPresent([LabyrinthNode].self, forKey: .nodes) ?? []
        discoveredBiomeIDs = try container.decodeIfPresent([String].self, forKey: .discoveredBiomeIDs) ?? []
        discoveredModifierIDs = try container.decodeIfPresent([String].self, forKey: .discoveredModifierIDs) ?? []
        claimedMilestoneDepths = try container.decodeIfPresent([Int].self, forKey: .claimedMilestoneDepths) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case worldSeed
        case deepestDepth
        case hasEntered
        case clusters
        case nodes
        case discoveredBiomeIDs
        case discoveredModifierIDs
        case claimedMilestoneDepths
    }

    func labyrinth() -> PlayerLabyrinthState {
        PlayerLabyrinthState(
            worldSeed: worldSeed,
            deepestDepth: deepestDepth,
            hasEntered: hasEntered,
            clusters: clusters,
            nodes: Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) }),
            discoveredBiomeIDs: Set(discoveredBiomeIDs),
            discoveredModifierIDs: Set(discoveredModifierIDs),
            claimedMilestoneDepths: Set(claimedMilestoneDepths)
        )
    }
}
