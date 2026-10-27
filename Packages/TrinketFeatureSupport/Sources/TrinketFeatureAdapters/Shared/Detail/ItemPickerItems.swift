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

    mutating func update(inventory: [InventoryItem], loadout: EquipmentLoadout, slot: ItemSlot, locale: Locale = .current) {
        let inventoryChanged = self.inventory != inventory
        let localeChanged = searchLocale != locale
        if !inventoryChanged, !localeChanged, lastLoadout == loadout, lastSlot == slot {
            return
        }
        if inventoryChanged || localeChanged {
            let previousItems = Dictionary(uniqueKeysWithValues: self.inventory.map { ($0.id, $0) })
            // Keep cached descriptions only while their item and locale are unchanged.
            searchText = Dictionary(uniqueKeysWithValues: inventory.compactMap { item in
                guard !localeChanged, previousItems[item.id] == item, let text = searchText[item.id] else { return nil }
                return (item.id, text)
            })
            self.inventory = inventory
            searchLocale = locale
        }
        let candidates = loadout.equippableItems(in: slot, inventory: inventory)
        // Other slots cannot appear in this picker, so defer their localization until eligible.
        for item in candidates where searchText[item.id] == nil {
            let fields = [item.localizedDisplayName(locale: locale), item.baseType.localizedName(locale: locale)]
                + item.displayedAffixes.flatMap {
                    [ContentCopy.localized($0.title, locale: locale), ContentCopy.localized($0.description, locale: locale)]
                }
                + item.keywords.map { $0.localizedName(locale: locale) }
            searchText[item.id] = Self.normalized(fields.joined(separator: " "), locale: locale)
        }
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
        let words = Self.normalized(filter.search, locale: searchLocale).split(whereSeparator: \.isWhitespace)
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
