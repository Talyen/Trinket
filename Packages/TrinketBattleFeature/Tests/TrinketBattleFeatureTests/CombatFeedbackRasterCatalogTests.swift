import Foundation
import SwiftUI
import Testing
import TrinketCore
import TrinketDesignSystem
@testable import BattleEngine
@testable import TrinketBattleFeature

struct CombatFeedbackRasterCatalogTests {
    @Test func `every closed vocabulary live presentation maps to A warmed key`() {
        let date = Date(timeIntervalSince1970: 1)
        let layoutDirection = LayoutDirection.leftToRight
        let displayScale: CGFloat = 3
        let warmed = Set(
            CombatFeedbackRasterCatalog.closedVocabularyItems(at: date).map {
                CombatFeedbackRasterKey(
                    item: $0,
                    layoutDirection: layoutDirection,
                    displayScale: displayScale,
                )
            },
        )

        for item in CombatFeedbackClosedVocabulary.enumerateWordChips(at: date) {
            let key = CombatFeedbackRasterKey(
                item: item,
                layoutDirection: layoutDirection,
                displayScale: displayScale,
            )
            #expect(
                warmed.contains(key),
                "missing warmup for \(item.feedbackClass) \(item.label) \(item.keyword)",
            )
        }
    }
}
