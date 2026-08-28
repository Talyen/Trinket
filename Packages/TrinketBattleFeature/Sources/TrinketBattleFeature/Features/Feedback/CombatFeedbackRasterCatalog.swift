import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

enum CombatFeedbackRasterCatalog {
    static func closedVocabularyItems(at date: Date = .now) -> [CombatFeedbackItem] {
        CombatFeedbackClosedVocabulary.enumerateItems(at: date)
    }

    static func closedVocabularyChips(at date: Date = .now) -> [CombatFeedbackItem] {
        CombatFeedbackOverlayPolicy.orderedChips(from: closedVocabularyItems(at: date))
    }

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
