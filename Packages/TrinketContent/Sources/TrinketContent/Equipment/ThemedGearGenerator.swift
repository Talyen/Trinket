import TrinketCore

public struct ThemedGearBuild: Equatable, Hashable, Sendable {
    public let inventory: [InventoryItem]
    public let loadout: EquipmentLoadout

    public init(inventory: [InventoryItem], loadout: EquipmentLoadout) {
        self.inventory = inventory
        self.loadout = loadout
    }
}

public struct ThemedGearGenerator: Sendable {
    public var itemGenerator: ItemGenerator
    public var baseTypes: [ItemBaseType]

    public init(
        itemGenerator: ItemGenerator = ItemGenerator(),
        baseTypes: [ItemBaseType] = GameContent.itemBaseTypes,
        includeTrinkets: Bool = false,
    ) {
        self.itemGenerator = itemGenerator
        self.baseTypes = includeTrinkets ? baseTypes : baseTypes.filter { $0.slot != .trinket }
    }

    public func generate(
        for combatant: Combatant,
        rarity: Rarity,
        fixedAffixCount: Int,
        idPrefix: String,
        keywordBias: Set<Keyword>? = nil,
        requireBuildAlignment: Bool = false,
        singlePiece: Bool = false,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ThemedGearBuild {
        let resolvedBias = keywordBias ?? combatant.keywordProfile
        var trinketsByBase: [ItemBaseType: InventoryItem] = [:]
        if baseTypes.contains(where: { $0.slot == .trinket }) {
            for trinket in GameContent.trinketItems where trinketsByBase[trinket.baseType] == nil {
                trinketsByBase[trinket.baseType] = trinket
            }
        }
        var slots = combatant.role.equipmentSlots
        if singlePiece {
            slots.shuffle(using: &randomNumberGenerator)
        }
        let trinketBases = Set(trinketsByBase.keys)
        var inventory: [InventoryItem] = []
        var loadout = EquipmentLoadout()
        for slot in slots {
            let id = "\(idPrefix)-\(combatant.id)-\(slot.rawValue)"
            guard let baseType = bestBaseType(
                for: slot, itemID: id, keywordBias: resolvedBias,
                requireBuildAlignment: requireBuildAlignment, loadout: loadout, inventory: inventory,
                trinketBases: trinketBases,
                using: &randomNumberGenerator,
            ) else { continue }
            let item = trinketsByBase[baseType] ?? itemGenerator.generate(
                id: id, baseType: baseType, rarity: rarity, fixedAffixCount: fixedAffixCount,
                keywordBias: resolvedBias, requireBuildAlignment: requireBuildAlignment,
                using: &randomNumberGenerator,
            )
            inventory.append(item)
            loadout.equip(item, in: slot, inventory: inventory)
            if singlePiece {
                break
            }
        }
        return ThemedGearBuild(inventory: inventory, loadout: loadout)
    }

    // swiftlint:disable:next function_parameter_count - gear entry points share the same roll and equipment context
    private func bestBaseType(
        for slot: ItemSlot,
        itemID: String,
        keywordBias: Set<Keyword>,
        requireBuildAlignment: Bool,
        loadout: EquipmentLoadout,
        inventory: [InventoryItem],
        trinketBases: Set<ItemBaseType>,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemBaseType? {
        var candidates: [ItemBaseType] = []
        var maximumAffinity = -1
        for baseType in baseTypes {
            guard loadout.canEquip(baseType: baseType, candidateID: itemID, in: slot, inventory: inventory) else {
                continue
            }
            if baseType.slot == .trinket {
                guard trinketBases.contains(baseType) else { continue }
                if requireBuildAlignment {
                    guard GameContent.itemAffixDefinition(matching: baseType.id)?
                        .isAligned(withBuildKeywords: keywordBias) == true else { continue }
                }
            } else if requireBuildAlignment {
                guard itemGenerator.affixDefinitions.contains(where: {
                    $0.weight > 0 && $0.isEligible(for: baseType) && $0.isAligned(withBuildKeywords: keywordBias)
                }) else { continue }
            }
            let affinity = baseType.keywordAffinities.count(where: keywordBias.contains)
            if affinity > maximumAffinity {
                maximumAffinity = affinity
                candidates.removeAll(keepingCapacity: true)
            }
            if affinity == maximumAffinity {
                candidates.append(baseType)
            }
        }
        return candidates.randomElement(using: &randomNumberGenerator)
    }
}
