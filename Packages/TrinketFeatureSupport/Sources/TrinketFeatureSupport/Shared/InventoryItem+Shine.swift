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

    var displayTextShine: Shine {
        if rarity == .unique {
            return .itemText(colors: Shine.uniqueBorderColors)
        }
        guard isTrinket || rarity == .astral else { return .none }
        let described = Set(displayedAffixes.flatMap { Keyword.referenced(in: $0.description) })
        let ordered = described.sorted { $0.rawValue < $1.rawValue }
        let preferred = ordered.filter { baseType.keywordAffinities.contains($0) }
        let remaining = ordered.filter { !baseType.keywordAffinities.contains($0) }
        return .itemText(colors: (preferred + remaining).prefix(3).map(\.visualStyle.color))
    }

    func affixShine(at index: Int, affix: ItemAffix) -> Shine {
        if rarity == .unique {
            return .itemText(colors: Shine.uniqueBorderColors)
        }
        if affix.isCorrupted {
            return .corruption
        }
        guard isPerfectAffix(at: index) else { return .none }
        let keywords = Keyword.referenced(in: affix.description).prefix(3)
        return .itemText(colors: keywords.map(\.visualStyle.color))
    }

    private var orderedAffinityKeywords: [Keyword] {
        Keyword.allCases.filter { keywords.contains($0) }
    }
}
