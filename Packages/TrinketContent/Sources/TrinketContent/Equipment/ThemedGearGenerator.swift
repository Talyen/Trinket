import Foundation
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
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ThemedGearBuild {
        let resolvedBias = keywordBias ?? combatant.keywordProfile
        var inventory: [InventoryItem] = []
        var loadout = EquipmentLoadout()

        for slot in combatant.role.equipmentSlots {
            guard let item = makeItem(
                for: slot,
                combatant: combatant,
                rarity: rarity,
                fixedAffixCount: fixedAffixCount,
                idPrefix: idPrefix,
                resolvedBias: resolvedBias,
                requireBuildAlignment: requireBuildAlignment,
                loadout: loadout,
                inventory: inventory,
                using: &randomNumberGenerator,
            ) else { continue }
            inventory.append(item)
            loadout.equip(item, in: slot, inventory: inventory)
        }

        return ThemedGearBuild(inventory: inventory, loadout: loadout)
    }

    public func generateSinglePiece(
        for combatant: Combatant,
        rarity: Rarity,
        fixedAffixCount: Int,
        idPrefix: String,
        keywordBias: Set<Keyword>? = nil,
        requireBuildAlignment: Bool = false,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ThemedGearBuild {
        let resolvedBias = keywordBias ?? combatant.keywordProfile
        var remaining = combatant.role.equipmentSlots
        remaining.shuffle(using: &randomNumberGenerator)
        var loadout = EquipmentLoadout()
        for slot in remaining {
            guard let item = makeItem(
                for: slot,
                combatant: combatant,
                rarity: rarity,
                fixedAffixCount: fixedAffixCount,
                idPrefix: idPrefix,
                resolvedBias: resolvedBias,
                requireBuildAlignment: requireBuildAlignment,
                loadout: loadout,
                inventory: [],
                using: &randomNumberGenerator,
            ) else { continue }
            loadout.equip(item, in: slot, inventory: [item])
            return ThemedGearBuild(inventory: [item], loadout: loadout)
        }
        return ThemedGearBuild(inventory: [], loadout: loadout)
    }

    // swiftlint:disable:next function_parameter_count - item generation requires the complete roll context
    private func makeItem(
        for slot: ItemSlot,
        combatant: Combatant,
        rarity: Rarity,
        fixedAffixCount: Int,
        idPrefix: String,
        resolvedBias: Set<Keyword>,
        requireBuildAlignment: Bool,
        loadout: EquipmentLoadout,
        inventory: [InventoryItem],
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem? {
        let id = "\(idPrefix)-\(combatant.id)-\(slot.rawValue)"
        guard let baseType = bestBaseType(
            for: slot,
            itemID: id,
            keywordBias: resolvedBias,
            requireBuildAlignment: requireBuildAlignment,
            loadout: loadout,
            inventory: inventory,
            using: &randomNumberGenerator,
        ) else { return nil }
        return itemGenerator.generate(
            id: id,
            baseType: baseType,
            rarity: rarity,
            fixedAffixCount: fixedAffixCount,
            keywordBias: resolvedBias,
            requireBuildAlignment: requireBuildAlignment,
            using: &randomNumberGenerator,
        )
    }

    private func bestBaseType(
        for slot: ItemSlot,
        itemID: String,
        keywordBias: Set<Keyword>,
        requireBuildAlignment: Bool,
        loadout: EquipmentLoadout,
        inventory: [InventoryItem],
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemBaseType? {
        var candidates = baseTypes.filter {
            loadout.canEquip(baseType: $0, candidateID: itemID, in: slot, inventory: inventory)
        }
        if requireBuildAlignment {
            candidates = candidates.filter { baseType in
                itemGenerator.affixDefinitions.contains { definition in
                    definition.isEligible(for: baseType)
                        && definition.isAligned(withBuildKeywords: keywordBias)
                }
            }
        }
        guard !candidates.isEmpty else { return nil }
        return ItemBasePolicy.maxAffinityBase(
            from: candidates,
            keywordBias: keywordBias,
            using: &randomNumberGenerator,
        )
    }
}
