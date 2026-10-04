import TrinketContent

enum InventoryDuplicatePolicy {
    static func containsDuplicate(of candidate: InventoryItem, in items: [InventoryItem]) -> Bool {
        items.contains {
            $0.id == candidate.id || ($0.templateID == candidate.templateID
                && (($0.isTrinket && candidate.isTrinket) || ($0.rarity == .unique && candidate.rarity == .unique)))
        }
    }

    static func deduplicated(_ items: [InventoryItem]) -> [InventoryItem] {
        var result: [InventoryItem] = []
        result.reserveCapacity(items.count)
        appendUniqueItems(items, to: &result)
        return result
    }

    static func appendUniqueItems(_ candidates: some Sequence<InventoryItem>, to items: inout [InventoryItem]) {
        var instances = Set(items.map(\.id))
        var trinkets = Set(items.lazy.filter(\.isTrinket).map(\.templateID))
        var uniques = Set(items.lazy.filter { $0.rarity == .unique }.map(\.templateID))
        for item in candidates {
            guard !instances.contains(item.id),
                  !item.isTrinket || !trinkets.contains(item.templateID),
                  item.rarity != .unique || !uniques.contains(item.templateID) else { continue }
            // A rejected item must not reserve any of its other ownership keys.
            instances.insert(item.id)
            if item.isTrinket {
                trinkets.insert(item.templateID)
            }
            if item.rarity == .unique {
                uniques.insert(item.templateID)
            }
            items.append(item)
        }
    }
}
