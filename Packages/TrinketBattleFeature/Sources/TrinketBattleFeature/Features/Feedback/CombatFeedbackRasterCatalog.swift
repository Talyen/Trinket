import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

/// Finite chip templates that can be composed before the first publish frame.
///
/// Numeric magnitudes are intentionally excluded: amounts are unbounded, and the
/// glyph atlas already prewarms the full digit alphabet so warm numeric blits stay
/// sub-millisecond. Caching every magnitude × keyword would cost tens of thousands
/// of CGImages.
enum CombatFeedbackRasterCatalog {
    /// Every closed (non-numeric) chip the presenter can emit, in both headline and
    /// secondary roles so dense groups stay cache-warm.
    static func closedVocabularyItems(at date: Date = .now) -> [CombatFeedbackItem] {
        CombatFeedbackClosedVocabulary.enumerateItems(at: date)
    }

    static func closedVocabularyChips(at date: Date = .now) -> [CombatFeedbackItem] {
        // Prepare every action group in the batch — not only the single newest group
        // the overlay keeps on-screen — so staggered targets are warm before availableAt.
        CombatFeedbackOverlayPolicy.orderedChips(from: closedVocabularyItems(at: date))
    }

    /// Unique short word texts drawn next to a keyword icon, derived from the
    /// closed-vocabulary catalog rather than a parallel keyword inventory.
    static func wordAtlasFragments(for typography: CombatFeedbackTypographyTier) -> [String] {
        var seen: Set<String> = []
        var fragments: [String] = []
        for item in closedVocabularyItems() where item.feedbackClass.typographyTier == typography {
            guard let text = item.chipPresentation.text, !text.isEmpty else { continue }
            if seen.insert(text).inserted {
                fragments.append(text)
            }
        }
        return fragments
    }
}
