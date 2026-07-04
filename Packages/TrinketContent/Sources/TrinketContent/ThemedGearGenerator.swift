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
        baseTypes: [ItemBaseType] = GameContent.itemBaseTypes
    ) {
        self.itemGenerator = itemGenerator
        self.baseTypes = baseTypes
    }

    public func generate<RNG: RandomNumberGenerator>(
        for combatant: Combatant,
        rarity: Rarity,
        fixedAffixCount: Int,
        idPrefix: String,
        using randomNumberGenerator: inout RNG
    ) -> ThemedGearBuild {
        let keywordBias = combatant.keywordProfile
        var inventory: [InventoryItem] = []
        var loadout = EquipmentLoadout()

        for slot in combatant.role.equipmentSlots {
            guard let baseType = bestBaseType(
                for: slot.baseItemSlot,
                keywordBias: keywordBias,
                using: &randomNumberGenerator
            ) else {
                continue
            }

            let itemID = "\(idPrefix)-\(combatant.id)-\(slot.rawValue)"
            let item = itemGenerator.generate(
                id: itemID,
                baseType: baseType,
                rarity: rarity,
                fixedAffixCount: fixedAffixCount,
                keywordBias: keywordBias,
                using: &randomNumberGenerator
            )
            inventory.append(item)
            loadout.equip(item, in: slot)
        }

        return ThemedGearBuild(inventory: inventory, loadout: loadout)
    }

    private func bestBaseType<RNG: RandomNumberGenerator>(
        for slot: ItemSlot,
        keywordBias: Set<Keyword>,
        using randomNumberGenerator: inout RNG
    ) -> ItemBaseType? {
        let candidates = baseTypes.filter { $0.slot == slot }
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
