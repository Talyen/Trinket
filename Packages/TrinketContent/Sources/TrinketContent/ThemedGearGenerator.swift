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
    ) {
        self.itemGenerator = itemGenerator
        self.baseTypes = baseTypes.filter { $0.slot != .trinket }
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
            guard loadout.isAvailable(slot, inventory: inventory) else { continue }
            guard let item = makeItem(
                for: slot,
                combatant: combatant,
                rarity: rarity,
                fixedAffixCount: fixedAffixCount,
                idPrefix: idPrefix,
                resolvedBias: resolvedBias,
                requireBuildAlignment: requireBuildAlignment,
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
            guard loadout.isAvailable(slot, inventory: []) else { continue }
            guard let item = makeItem(
                for: slot,
                combatant: combatant,
                rarity: rarity,
                fixedAffixCount: fixedAffixCount,
                idPrefix: idPrefix,
                resolvedBias: resolvedBias,
                requireBuildAlignment: requireBuildAlignment,
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
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem? {
        guard let baseType = bestBaseType(
            for: slot,
            keywordBias: resolvedBias,
            requireBuildAlignment: requireBuildAlignment,
            using: &randomNumberGenerator,
        ) else { return nil }
        return itemGenerator.generate(
            id: "\(idPrefix)-\(combatant.id)-\(slot.rawValue)",
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
        keywordBias: Set<Keyword>,
        requireBuildAlignment: Bool,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemBaseType? {
        var candidates = baseTypes.filter { $0.canEquip(in: slot) }
        if requireBuildAlignment {
            candidates = candidates.filter { baseType in
                itemGenerator.affixDefinitions.contains { definition in
                    definition.isEligible(for: baseType)
                        && definition.isAligned(withBuildKeywords: keywordBias)
                }
            }
        }
        guard !candidates.isEmpty else { return nil }

        let ranked = candidates.map { baseType -> (ItemBaseType, Int) in
            let overlap = baseType.keywordAffinities.intersection(keywordBias).count
            return (baseType, overlap)
        }
        let maxOverlap = ranked.map(\.1).max() ?? 0
        let topCandidates = ranked.filter { $0.1 == maxOverlap }.map(\.0)
        return topCandidates.randomElement(using: &randomNumberGenerator)
    }
}
