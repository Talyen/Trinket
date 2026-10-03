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
        build(
            for: combatant, rarity: rarity, fixedAffixCount: fixedAffixCount, idPrefix: idPrefix,
            keywordBias: keywordBias, requireBuildAlignment: requireBuildAlignment,
            singlePiece: false, using: &randomNumberGenerator,
        )
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
        build(
            for: combatant, rarity: rarity, fixedAffixCount: fixedAffixCount, idPrefix: idPrefix,
            keywordBias: keywordBias, requireBuildAlignment: requireBuildAlignment,
            singlePiece: true, using: &randomNumberGenerator,
        )
    }

    // swiftlint:disable:next function_parameter_count - both gear entry points share the same roll and equipment context
    private func build(
        for combatant: Combatant,
        rarity: Rarity,
        fixedAffixCount: Int,
        idPrefix: String,
        keywordBias: Set<Keyword>?,
        requireBuildAlignment: Bool,
        singlePiece: Bool,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ThemedGearBuild {
        let resolvedBias = keywordBias ?? combatant.keywordProfile
        var slots = combatant.role.equipmentSlots
        if singlePiece {
            slots.shuffle(using: &randomNumberGenerator)
        }
        var inventory: [InventoryItem] = []
        var loadout = EquipmentLoadout()
        for slot in slots {
            let id = "\(idPrefix)-\(combatant.id)-\(slot.rawValue)"
            guard let baseType = bestBaseType(
                for: slot, itemID: id, keywordBias: resolvedBias,
                requireBuildAlignment: requireBuildAlignment, loadout: loadout, inventory: inventory,
                using: &randomNumberGenerator,
            ) else { continue }
            let item = itemGenerator.generate(
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

    private func bestBaseType(
        for slot: ItemSlot,
        itemID: String,
        keywordBias: Set<Keyword>,
        requireBuildAlignment: Bool,
        loadout: EquipmentLoadout,
        inventory: [InventoryItem],
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemBaseType? {
        let candidates = baseTypes.filter { baseType in
            guard loadout.canEquip(baseType: baseType, candidateID: itemID, in: slot, inventory: inventory) else {
                return false
            }
            guard requireBuildAlignment else { return true }
            return itemGenerator.affixDefinitions.contains { definition in
                definition.isEligible(for: baseType)
                    && definition.isAligned(withBuildKeywords: keywordBias)
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
