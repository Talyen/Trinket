import TrinketContent
import TrinketCore

enum InventoryDuplicatePolicy {
    static func isDuplicate(_ lhs: InventoryItem, _ rhs: InventoryItem) -> Bool {
        lhs.id == rhs.id
            || (lhs.isTrinket && rhs.isTrinket && lhs.templateID == rhs.templateID)
            || (lhs.rarity == .unique && rhs.rarity == .unique && lhs.templateID == rhs.templateID)
    }

    static func deduplicated(_ items: [InventoryItem]) -> [InventoryItem] {
        var seenIDs = Set<String>()
        var seenTrinketIDs = Set<String>()
        var seenUniqueIDs = Set<String>()
        return items.filter { item in
            guard !seenIDs.contains(item.id) else { return false }
            if item.isTrinket {
                guard seenTrinketIDs.insert(item.templateID).inserted else { return false }
            }
            if item.rarity == .unique {
                guard seenUniqueIDs.insert(item.templateID).inserted else { return false }
            }
            seenIDs.insert(item.id)
            return true
        }
    }

    static func containsDuplicate(of candidate: InventoryItem, in items: [InventoryItem]) -> Bool {
        items.contains { isDuplicate($0, candidate) }
    }
}
