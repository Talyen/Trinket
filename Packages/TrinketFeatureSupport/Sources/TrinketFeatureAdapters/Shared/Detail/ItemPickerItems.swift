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
    private var lastLoadout = EquipmentLoadout()
    private var lastSlot: ItemSlot?
    private var searchText: [String: String] = [:]
    private var searchLocale = Locale.current
    private var order: [String: Int] = [:]
    private(set) var eligible: [InventoryItem] = []
    private(set) var keywords: [Keyword] = []

    mutating func update(inventory: [InventoryItem], loadout: EquipmentLoadout, slot: ItemSlot) {
        let locale = Locale.current
        let inventoryChanged = self.inventory != inventory
        let localeChanged = searchLocale != locale
        if !inventoryChanged, !localeChanged, lastLoadout == loadout, lastSlot == slot {
            return
        }
        if inventoryChanged || localeChanged {
            let previousItems = Dictionary(uniqueKeysWithValues: self.inventory.map { ($0.id, $0) })
            // Reuse descriptions only for equal items in the same normalization locale.
            searchText = Dictionary(uniqueKeysWithValues: inventory.map { item in
                if !localeChanged, previousItems[item.id] == item, let text = searchText[item.id] {
                    return (item.id, text)
                }
                let fields = [item.displayName, item.baseType.name]
                    + item.displayedAffixes.flatMap { [$0.title, $0.description] }
                    + item.keywords.map(\.rawValue)
                return (item.id, Self.normalized(fields.joined(separator: " "), locale: locale))
            })
            self.inventory = inventory
            searchLocale = locale
        }
        let candidates = loadout.equippableItems(in: slot, inventory: inventory)
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
        let newItems = candidates.filter { order[$0.id] == nil }
        if !newItems.isEmpty {
            for item in newItems.sorted(by: Self.precedes) {
                order[item.id] = order.count
            }
        }
        eligible = candidates.sorted { order[$0.id, default: 0] < order[$1.id, default: 0] }
        var candidateKeywords = Set<Keyword>()
        for candidate in candidates {
            for affix in candidate.affixes {
                candidateKeywords.formUnion(affix.keywords)
            }
        }
        keywords = candidateKeywords.sorted {
            $0.rawValue.localizedStandardCompare($1.rawValue) == .orderedAscending
        }
        lastLoadout = loadout
        lastSlot = slot
    }

    func matching(_ filter: ItemPickerFilter) -> [InventoryItem] {
        let words = Self.normalized(filter.search).split(whereSeparator: \.isWhitespace)
        return eligible.filter { item in
            (filter.rarity == nil || item.rarity == filter.rarity)
                && (filter.keyword.map { keyword in item.affixes.contains { $0.keywords.contains(keyword) } } ?? true)
                && words.allSatisfy { searchText[item.id, default: ""].contains($0) }
        }
    }

    private static func normalized(_ text: String, locale: Locale = .current) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
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
