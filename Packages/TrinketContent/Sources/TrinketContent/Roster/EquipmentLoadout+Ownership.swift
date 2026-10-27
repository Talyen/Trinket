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
        if let combatantID {
            orderedIDs.removeAll { $0 == combatantID }
            orderedIDs.insert(combatantID, at: 0)
        }
        var claimedItemIDs = Set<String>()
        var unique: [String: EquipmentLoadout] = [:]
        for combatantID in orderedIDs {
            guard let loadout = loadouts[combatantID] else { continue }
            var slots: [ItemSlot: String] = [:]
            for slot in ItemSlot.allCases {
                guard let itemID = loadout.itemID(for: slot), claimedItemIDs.insert(itemID).inserted else { continue }
                slots[slot] = itemID
            }
            unique[combatantID] = EquipmentLoadout(itemIDsBySlot: slots)
        }
        return unique
    }
}
