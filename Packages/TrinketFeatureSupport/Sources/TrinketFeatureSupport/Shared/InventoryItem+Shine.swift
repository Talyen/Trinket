import SwiftUI
import Synchronization
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public extension InventoryItem {
    var astralShineKeywords: [Keyword] {
        guard isTrinket || rarity == .astral else { return [] }
        return orderedAffinityKeywords
    }

    var astralShine: Shine {
        let keywords = astralShineKeywords
        return keywords.isEmpty ? .none : .keywords(keywords)
    }

    var plasmaKeywords: [Keyword] {
        orderedAffinityKeywords
    }

    var displayShine: Shine {
        if rarity == .unique {
            return .unique
        }
        return astralShine
    }

    var displayTextShine: Shine {
        if rarity == .unique {
            return .itemText(colors: Shine.uniqueBorderColors)
        }
        guard isTrinket || rarity == .astral else { return .none }
        return InventoryItemTextShineCache.value(for: self) {
            let described = Set(displayedAffixes.flatMap { Keyword.referenced(in: $0.description) })
            let ordered = described.sorted { $0.rawValue < $1.rawValue }
            let preferred = ordered.filter { baseType.keywordAffinities.contains($0) }
            let remaining = ordered.filter { !baseType.keywordAffinities.contains($0) }
            return .itemText(colors: (preferred + remaining).prefix(3).map(\.visualStyle.color))
        }
    }

    func affixShine(at index: Int, affix: ItemAffix) -> Shine {
        if rarity == .unique && isUniqueSignatureAffix(at: index) {
            return .itemText(colors: Shine.uniqueBorderColors)
        }
        if affix.isCorrupted {
            return .corruption
        }
        guard rarity == .unique || isPerfectAffix(at: index) else { return .none }
        let keywords = Keyword.referenced(in: affix.description).prefix(3)
        return .itemText(colors: keywords.map(\.visualStyle.color))
    }

    private var orderedAffinityKeywords: [Keyword] {
        let itemKeywords = keywords
        return Keyword.allCases.filter { itemKeywords.contains($0) }
    }
}

private enum InventoryItemTextShineCache {
    private struct State {
        var values: [InventoryItem: Shine] = [:]
        var keys: [InventoryItem] = []
        var nextSlot = 0
    }

    private static let state = Mutex(State())
    private static let capacity = 200

    static func value(for item: InventoryItem, make: () -> Shine) -> Shine {
        if let cached = state.withLock({ $0.values[item] }) {
            return cached
        }
        // Derive outside the lock; full value keys prevent stale appearance after item changes.
        let value = make()
        return state.withLock { state in
            if let cached = state.values[item] {
                return cached
            }
            if state.keys.count == capacity {
                state.values.removeValue(forKey: state.keys[state.nextSlot])
                state.keys[state.nextSlot] = item
                state.nextSlot = (state.nextSlot + 1) % capacity
            } else {
                state.keys.append(item)
            }
            // Cache semantic colors so environment-dependent color resolution remains live.
            state.values[item] = value
            return value
        }
    }
}
