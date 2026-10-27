public enum InventoryDuplicatePolicy {
    public static func containsDuplicate(of candidate: InventoryItem, in items: [InventoryItem]) -> Bool {
        items.contains {
            $0.id == candidate.id || ($0.templateID == candidate.templateID
                && (($0.isTrinket && candidate.isTrinket) || ($0.rarity == .unique && candidate.rarity == .unique)))
        }
    }

    public static func deduplicated(_ items: [InventoryItem]) -> [InventoryItem] {
        var result: [InventoryItem] = []
        result.reserveCapacity(items.count)
        appendUniqueItems(items, to: &result)
        return result
    }

    public static func appendUniqueItems(_ candidates: some Sequence<InventoryItem>, to items: inout [InventoryItem]) {
        var instances: Set<String> = []
        var trinkets: Set<String> = []
        var uniques: Set<String> = []
        for item in items {
            instances.insert(item.id)
            if item.isTrinket {
                trinkets.insert(item.templateID)
            }
            if item.rarity == .unique {
                uniques.insert(item.templateID)
            }
        }
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
