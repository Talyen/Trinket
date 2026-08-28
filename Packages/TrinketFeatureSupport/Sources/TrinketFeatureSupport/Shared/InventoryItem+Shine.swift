import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public extension InventoryItem {
    var astralShineKeywords: [Keyword]? {
        guard rarity == .astral else { return nil }
        return orderedAffinityKeywords
    }

    var astralShineKeywordSet: Set<Keyword> {
        guard let keywords = astralShineKeywords else { return [] }
        return Set(keywords)
    }

    var plasmaKeywords: [Keyword] {
        orderedAffinityKeywords
    }

    private var orderedAffinityKeywords: [Keyword] {
        let source = keywords.isEmpty ? baseType.keywordAffinities : keywords
        return Keyword.allCases.filter { source.contains($0) }
    }
}
