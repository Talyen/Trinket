import TrinketContent

enum InventoryDuplicatePolicy {
    private enum OwnershipKey: Hashable {
        case instance(String)
        case trinket(String)
        case unique(String)
    }

    private static func ownershipKeys(for item: InventoryItem) -> [OwnershipKey] {
        var keys: [OwnershipKey] = [.instance(item.id)]
        if item.isTrinket {
            keys.append(.trinket(item.templateID))
        }
        if item.rarity == .unique {
            keys.append(.unique(item.templateID))
        }
        return keys
    }

    static func containsDuplicate(of candidate: InventoryItem, in items: [InventoryItem]) -> Bool {
        let keys = Set(ownershipKeys(for: candidate))
        return items.contains { !keys.isDisjoint(with: ownershipKeys(for: $0)) }
    }

    static func deduplicated(_ items: [InventoryItem]) -> [InventoryItem] {
        var result: [InventoryItem] = []
        result.reserveCapacity(items.count)
        appendUniqueItems(items, to: &result)
        return result
    }

    static func appendUniqueItems(_ candidates: some Sequence<InventoryItem>, to items: inout [InventoryItem]) {
        var claimed = Set<OwnershipKey>()
        for item in items {
            claimed.formUnion(ownershipKeys(for: item))
        }
        for item in candidates {
            let keys = ownershipKeys(for: item)
            guard !keys.contains(where: claimed.contains) else { continue }
            // A rejected item must not reserve any of its other ownership keys.
            claimed.formUnion(keys)
            items.append(item)
        }
    }
}
