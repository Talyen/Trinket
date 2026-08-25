import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public extension InventoryItem {
    /// Keyword shine for Astral items: rolled affix keywords when present, otherwise base-type affinities.
    var astralShineKeywords: [Keyword]? {
        guard rarity == .astral else { return nil }
        return orderedAffinityKeywords
    }

    var astralShineKeywordSet: Set<Keyword> {
        guard let keywords = astralShineKeywords else { return [] }
        return Set(keywords)
    }

    /// Keyword colors for ambient plasma: rolled affixes when present, otherwise base-type affinities.
    var plasmaKeywords: [Keyword] {
        orderedAffinityKeywords
    }

    /// `Keyword.allCases` order so shader/shine color pairing does not shuffle with `Set` iteration.
    private var orderedAffinityKeywords: [Keyword] {
        let source = keywords.isEmpty ? baseType.keywordAffinities : keywords
        return Keyword.allCases.filter { source.contains($0) }
    }
}
