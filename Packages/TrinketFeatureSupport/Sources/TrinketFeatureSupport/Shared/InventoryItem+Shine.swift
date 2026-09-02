import SwiftUI
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

    func affixShine(at index: Int, affix: ItemAffix) -> Shine {
        if rarity == .unique {
            return .unique
        }
        if affix.isCorrupted {
            return .corruption
        }
        let keywords = isPerfectAffix(at: index) ? Keyword.allCases.filter(affix.keywords.contains) : []
        return keywords.isEmpty ? .none : .keywords(keywords)
    }

    private var orderedAffinityKeywords: [Keyword] {
        Keyword.allCases.filter { keywords.contains($0) }
    }
}
