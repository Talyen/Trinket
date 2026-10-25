import TrinketCore

/// Shared headless/career heuristic; it does not rank gear for the player UI.
public enum SimulationEquipmentPolicy {
    public static let id = "aligned-affix-budget-v1"

    public struct Upgrade: Equatable, Sendable {
        public let itemID: String
        public let slot: ItemSlot
    }

    /// Retain ties, respect other owners, and compare the entire resulting legal
    /// loadout so replacing a primary includes any displaced secondary's cost.
    public static func nextUpgrade(
        for combatant: Combatant,
        inventory: [InventoryItem],
        loadout: EquipmentLoadout,
        reservedItemIDs: Set<String> = [],
    ) -> Upgrade? {
        let current = loadout.sanitized(for: combatant, inventory: inventory)
        let worn = Set(current.itemIDsBySlot.values)
        let keywords = Set(combatant.abilities.flatMap(\.keywords))
        let values = Dictionary(uniqueKeysWithValues: inventory.map { item in
            (item.id, value(item, for: combatant, keywords: keywords))
        })
        var best = score(current, values: values)
        var upgrade: Upgrade?
        for item in inventory.sorted(by: { $0.id < $1.id }) where !worn.contains(item.id) && !reservedItemIDs.contains(item.id) {
            for slot in combatant.role.equipmentSlots where current.canEquip(item, in: slot, inventory: inventory) {
                var candidate = current
                candidate.equip(item, in: slot, inventory: inventory)
                candidate = candidate.sanitized(for: combatant, inventory: inventory)
                let value = score(candidate, values: values)
                if value > best {
                    best = value
                    upgrade = Upgrade(itemID: item.id, slot: slot)
                }
            }
        }
        return upgrade
    }

    private static func value(_ item: InventoryItem, for combatant: Combatant, keywords: Set<Keyword>) -> Int {
        // Basic/Astral power tiers and two-handed affix multipliers are proxies,
        // not measured combat value. Off-build damage and unusable Mana score zero.
        let aligned = item.affixes.count { affix in
            let damage = affix.keywords.filter { $0.category == .damageType }
            return damage.isSubset(of: keywords) && (combatant.hasMana || !affix.keywords.contains(.mana))
        }
        return aligned * item.baseType.affixPowerMultiplier * (item.rarity == .basic ? 1 : 2)
            * (ItemSlot.allCases.count + 1) + 1
    }

    private static func score(_ loadout: EquipmentLoadout, values: [String: Int]) -> Int {
        // Slot count breaks budget ties but can never outweigh one budget point.
        Set(loadout.itemIDsBySlot.values).reduce(0) { $0 + values[$1, default: 0] }
    }
}
