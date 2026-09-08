import Foundation
import TrinketContent
import TrinketCore

struct ItemPickerFilter: Equatable {
    var search = ""
    var rarity: Rarity?
    var keyword: Keyword?

    var isActive: Bool {
        !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || rarity != nil || keyword != nil
    }
}

struct ItemPickerItems {
    private var inventory: [InventoryItem] = []
    private var searchText: [String: String] = [:]
    private var order: [String: Int] = [:]
    private(set) var eligible: [InventoryItem] = []
    private(set) var keywords: [Keyword] = []

    mutating func update(inventory: [InventoryItem], loadout: EquipmentLoadout, slot: ItemSlot) {
        if self.inventory != inventory {
            self.inventory = inventory
            searchText = Dictionary(uniqueKeysWithValues: inventory.map { item in
                let fields = [item.displayName, item.baseType.name]
                    + item.displayedAffixes.flatMap { [$0.title, $0.description] }
                    + item.keywords.map(\.rawValue)
                return (item.id, Self.normalized(fields.joined(separator: " ")))
            })
        }
        let candidates = inventory.filter { loadout.canEquip($0, in: slot, inventory: inventory) }
        if order.isEmpty {
            let equippedID = loadout.itemID(for: slot)
            let sorted = candidates.sorted { lhs, rhs in
                if (lhs.id == equippedID) != (rhs.id == equippedID) {
                    return lhs.id == equippedID
                }
                return Self.precedes(lhs, rhs)
            }
            order = Dictionary(uniqueKeysWithValues: sorted.enumerated().map { ($0.element.id, $0.offset) })
        }
        for item in candidates.sorted(by: Self.precedes) where order[item.id] == nil {
            order[item.id] = order.count
        }
        eligible = candidates.sorted { order[$0.id, default: 0] < order[$1.id, default: 0] }
        keywords = Set(candidates.flatMap(\.keywords)).sorted {
            $0.rawValue.localizedStandardCompare($1.rawValue) == .orderedAscending
        }
    }

    func matching(_ filter: ItemPickerFilter) -> [InventoryItem] {
        let words = Self.normalized(filter.search).split(whereSeparator: \.isWhitespace)
        return eligible.filter { item in
            (filter.rarity == nil || item.rarity == filter.rarity)
                && (filter.keyword.map { item.keywords.contains($0) } ?? true)
                && words.allSatisfy { searchText[item.id, default: ""].contains($0) }
        }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func rarityRank(_ rarity: Rarity) -> Int {
        switch rarity {
        case .unique: 0
        case .astral: 1
        case .basic: 2
        }
    }

    private static func precedes(_ lhs: InventoryItem, _ rhs: InventoryItem) -> Bool {
        if lhs.rarity != rhs.rarity {
            return rarityRank(lhs.rarity) < rarityRank(rhs.rarity)
        }
        let nameOrder = lhs.displayName.localizedStandardCompare(rhs.displayName)
        return nameOrder == .orderedSame ? lhs.id < rhs.id : nameOrder == .orderedAscending
    }
}
