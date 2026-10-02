import TrinketContent

public struct PlayerInventoryState: Equatable, Hashable, Sendable {
    public var items: [InventoryItem]

    public init(items: [InventoryItem]) {
        self.items = items
    }

    public static var freshStart: Self {
        Self(items: [])
    }

    public static var testSeed: Self {
        Self(items: GameContent.sampleInventoryItems)
    }

    public func item(matching id: String?) -> InventoryItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    public var ownedTrinketIDs: Set<String> {
        Set(items.lazy.filter(\.isTrinket).map(\.templateID))
    }

    public var ownedUniqueIDs: Set<String> {
        Set(items.lazy.filter { $0.rarity == .unique }.map(\.templateID))
    }

    public mutating func addRewardItem(from template: InventoryItem, for stage: Stage) {
        appendUniqueItem(template.rewardInstance(for: stage.id))
    }

    public mutating func appendUniqueItem(_ item: InventoryItem) {
        guard !InventoryDuplicatePolicy.containsDuplicate(of: item, in: items) else { return }
        items.append(item)
    }

    public mutating func removeItem(id: String) {
        items.removeAll { $0.id == id }
    }
}
