import TrinketCore

public extension EquipmentLoadout {
    /// Each physical item belongs to one slot across the party. An edited combatant
    /// claims items first; repair otherwise uses combatant ID and slot order.
    static func enforcingUniqueItems(
        in loadouts: [String: EquipmentLoadout],
        prioritizing combatantID: String? = nil,
    ) -> [String: EquipmentLoadout] {
        guard !loadouts.isEmpty else { return loadouts }
        var orderedIDs = loadouts.keys.sorted()
        if let combatantID, let index = orderedIDs.firstIndex(of: combatantID), index > 0 {
            orderedIDs.remove(at: index)
            orderedIDs.insert(combatantID, at: 0)
        }
        var claimedItemIDs = Set<String>()
        var unique: [String: EquipmentLoadout] = [:]
        unique.reserveCapacity(loadouts.count)
        for combatantID in orderedIDs {
            guard let loadout = loadouts[combatantID] else { continue }
            guard !loadout.itemIDsBySlot.isEmpty else {
                unique[combatantID] = loadout
                continue
            }
            var slots: [ItemSlot: String] = [:]
            for slot in ItemSlot.allCases {
                guard let itemID = loadout.itemID(for: slot), claimedItemIDs.insert(itemID).inserted else { continue }
                slots[slot] = itemID
            }
            unique[combatantID] = slots.count == loadout.itemIDsBySlot.count
                ? loadout
                : EquipmentLoadout(itemIDsBySlot: slots)
        }
        return unique
    }
}
