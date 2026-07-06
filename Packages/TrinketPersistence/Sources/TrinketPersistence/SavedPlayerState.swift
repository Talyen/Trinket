import Foundation
import TrinketContent
import TrinketCore

public struct SavedAbilityLoadout: Codable, Equatable, Sendable {
    var basicID: String?
    var skillID: String?
    var ultimateID: String?

    public init(_ loadout: AbilityLoadout) {
        basicID = loadout.basic?.id
        skillID = loadout.skill?.id
        ultimateID = loadout.ultimate?.id
    }

    func merged(with other: SavedAbilityLoadout, preferOther: Bool) -> SavedAbilityLoadout {
        func mergedSlot(_ local: String?, _ remote: String?) -> String? {
            switch (local, remote) {
            case let (local?, remote?) where local != remote:
                return preferOther ? remote : local
            case let (local?, nil):
                return local
            case let (nil, remote?):
                return remote
            default:
                return nil
            }
        }

        var merged = self
        merged.basicID = mergedSlot(basicID, other.basicID)
        merged.skillID = mergedSlot(skillID, other.skillID)
        merged.ultimateID = mergedSlot(ultimateID, other.ultimateID)
        return merged
    }

    public func loadout(defaults: AbilityLoadout, choices: AbilityChoices) -> AbilityLoadout {
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

public struct SavedEquipmentLoadout: Codable, Equatable, Sendable {
    var itemIDsBySlot: [String: String]

    public init(_ loadout: EquipmentLoadout) {
        itemIDsBySlot = Dictionary(uniqueKeysWithValues: loadout.itemIDsBySlot.map { ($0.key.rawValue, $0.value) })
    }

    func merged(with other: SavedEquipmentLoadout, preferOther: Bool) -> SavedEquipmentLoadout {
        var mergedSlots = itemIDsBySlot
        for (slot, remoteItemID) in other.itemIDsBySlot {
            if let localItemID = mergedSlots[slot], localItemID != remoteItemID {
                mergedSlots[slot] = preferOther ? remoteItemID : localItemID
            } else {
                mergedSlots[slot] = mergedSlots[slot] ?? remoteItemID
            }
        }
        var merged = self
        merged.itemIDsBySlot = mergedSlots
        return merged
    }

    public func loadout(inventoryItemIDs: Set<String>) -> EquipmentLoadout {
        var resolved: [ItemSlot: String] = [:]
        for (slotRawValue, itemID) in itemIDsBySlot {
            guard let slot = ItemSlot(rawValue: slotRawValue), inventoryItemIDs.contains(itemID) else { continue }
            resolved[slot] = itemID
        }
        return EquipmentLoadout(itemIDsBySlot: resolved)
    }
}

public struct SavedItemAffix: Codable, Equatable, Sendable {
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        keywordRawValues = try container.decode([String].self, forKey: .keywordRawValues)
    }

    public func affix() -> ItemAffix? {
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

public struct SavedInventoryItem: Codable, Equatable, Sendable {
    var id: String
    var templateID: String
    var baseTypeID: String
    var rarity: Rarity
    var displayName: String
    var affixes: [SavedItemAffix]

    init(_ item: InventoryItem) {
        id = item.id
        templateID = item.templateID
        baseTypeID = item.baseType.id
        rarity = item.rarity
        displayName = item.displayName
        affixes = item.affixes.map(SavedItemAffix.init)
    }

    public func item() -> InventoryItem? {
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

public struct SavedRosterState: Codable, Equatable, Sendable {
    public var activeHeroID: String
    public var activePetID: String
    public var unlockedHeroIDs: [String]
    public var unlockedPetIDs: [String]
    public var abilityLoadouts: [String: SavedAbilityLoadout]
    public var progressions: [String: CombatantProgression]
    public var equipmentLoadouts: [String: SavedEquipmentLoadout]
    public var gold: Int
    public var primaryStats: [String: PrimaryStats]

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

    public init(_ roster: PlayerRosterState) {
        activeHeroID = roster.activeHeroID
        activePetID = roster.activePetID
        unlockedHeroIDs = roster.unlockedHeroIDs.sorted()
        unlockedPetIDs = roster.unlockedPetIDs.sorted()
        abilityLoadouts = roster.abilityLoadouts.mapValues(SavedAbilityLoadout.init)
        progressions = roster.progressions
        equipmentLoadouts = roster.equipmentLoadouts.mapValues(SavedEquipmentLoadout.init)
        gold = roster.gold
        primaryStats = roster.primaryStatOverrides
    }

    public init(
        activeHeroID: String,
        activePetID: String,
        unlockedHeroIDs: [String],
        unlockedPetIDs: [String],
        abilityLoadouts: [String: SavedAbilityLoadout],
        progressions: [String: CombatantProgression],
        equipmentLoadouts: [String: SavedEquipmentLoadout],
        gold: Int,
        primaryStats: [String: PrimaryStats] = [:]
    ) {
        self.activeHeroID = activeHeroID
        self.activePetID = activePetID
        self.unlockedHeroIDs = unlockedHeroIDs
        self.unlockedPetIDs = unlockedPetIDs
        self.abilityLoadouts = abilityLoadouts
        self.progressions = progressions
        self.equipmentLoadouts = equipmentLoadouts
        self.gold = gold
        self.primaryStats = primaryStats
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeHeroID = try container.decode(String.self, forKey: .activeHeroID)
        activePetID = try container.decode(String.self, forKey: .activePetID)
        unlockedHeroIDs = try container.decodeIfPresent([String].self, forKey: .unlockedHeroIDs) ?? []
        unlockedPetIDs = try container.decodeIfPresent([String].self, forKey: .unlockedPetIDs) ?? []
        abilityLoadouts = try container.decode([String: SavedAbilityLoadout].self, forKey: .abilityLoadouts)
        progressions = try container.decode([String: CombatantProgression].self, forKey: .progressions)
        equipmentLoadouts = try container.decode([String: SavedEquipmentLoadout].self, forKey: .equipmentLoadouts)
        gold = try container.decode(Int.self, forKey: .gold)
        primaryStats = try container.decodeIfPresent([String: PrimaryStats].self, forKey: .primaryStats) ?? [:]
    }

    public func roster(inventoryItemIDs: Set<String>) -> PlayerRosterState {
        let unlockedHeroIDSet = Set(unlockedHeroIDs)
        let unlockedPetIDSet = Set(unlockedPetIDs)
        let (resolvedHeroID, resolvedPetID) = SavedRosterHydration.resolveActiveSelection(
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
            abilityLoadouts: SavedRosterHydration.resolveAbilityLoadouts(from: abilityLoadouts),
            progressions: progressions,
            equipmentLoadouts: SavedRosterHydration.resolveEquipmentLoadouts(
                from: equipmentLoadouts,
                inventoryItemIDs: inventoryItemIDs
            ),
            gold: gold,
            primaryStatOverrides: primaryStats
        )
    }
}

public struct SavedInventoryState: Codable, Equatable, Sendable {
    public var items: [SavedInventoryItem]

    public init(_ inventory: PlayerInventoryState) {
        items = inventory.items.map(SavedInventoryItem.init)
    }

    public func inventory() -> PlayerInventoryState {
        PlayerInventoryState(items: items.compactMap { $0.item() })
    }
}

public struct SavedHomesteadState: Codable, Equatable, Sendable {
    public var resources: [String: Int]
    public var nodeTiers: [String: Int]

    public init(_ homestead: PlayerHomesteadState) {
        resources = Dictionary(
            uniqueKeysWithValues: homestead.resources.map { ($0.key.rawValue, max($0.value, 0)) }
        )
        nodeTiers = Dictionary(
            uniqueKeysWithValues: homestead.nodeTiers.map { ($0.key.rawValue, max($0.value, 0)) }
        )
    }

    public func homestead() -> PlayerHomesteadState {
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
