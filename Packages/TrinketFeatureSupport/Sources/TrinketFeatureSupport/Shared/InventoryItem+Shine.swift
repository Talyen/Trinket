import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public extension InventoryItem {
    /// Keyword shine for Astral items: rolled affix keywords when present, otherwise base-type affinities.
    var astralShineKeywords: [Keyword]? {
        guard rarity == .astral else { return nil }
        return keywords.isEmpty ? Array(baseType.keywordAffinities) : Array(keywords)
    }

    var astralShineKeywordSet: Set<Keyword> {
        guard let keywords = astralShineKeywords else { return [] }
        return Set(keywords)
    }
}
