import Foundation
import SwiftUI
import Testing
import TrinketCore
import TrinketDesignSystem
@testable import BattleEngine
@testable import TrinketBattleFeature

struct CombatFeedbackRasterCatalogTests {
    /// Every closed-vocabulary chip the presenter can emit must hash to a key the
    /// warmup catalog already prepared. Numeric magnitudes stay on-demand.
    @Test func everyClosedVocabularyLivePresentationMapsToAWarmedKey() {
        let date = Date(timeIntervalSince1970: 1)
        let layoutDirection = LayoutDirection.leftToRight
        let displayScale: CGFloat = 3
        let warmed = Set(
            CombatFeedbackRasterCatalog.closedVocabularyItems(at: date).map {
                CombatFeedbackRasterKey(
                    item: $0,
                    layoutDirection: layoutDirection,
                    displayScale: displayScale
                )
            }
        )

        for item in liveWordChips(at: date) {
            let key = CombatFeedbackRasterKey(
                item: item,
                layoutDirection: layoutDirection,
                displayScale: displayScale
            )
            #expect(
                warmed.contains(key),
                "missing warmup for \(item.feedbackClass) \(item.label) \(item.keyword)"
            )
        }
    }

    /// Presenter-emitted word chips, not the catalog's closed-vocabulary filter.
    /// Numeric magnitudes stay on-demand and are excluded here.
    private func liveWordChips(at date: Date) -> [CombatFeedbackItem] {
        var items: [CombatFeedbackItem] = []
        for outcome in ActionEvent.EffectOutcome.allCases {
            for keyword in Keyword.allCases {
                let event = ActionEvent(
                    id: 1,
                    actionID: 1,
                    kind: .effect,
                    effectKind: outcome,
                    actorName: "Hero",
                    abilityName: "Catalog",
                    targetID: "catalog",
                    targetName: "Catalog",
                    amount: 1,
                    keyword: keyword
                )
                for presented in CombatFeedbackPresenter.makeItems(from: [event], at: date) {
                    guard case .word = presented.label else { continue }
                    for role in CombatFeedbackPresentationRole.allCases {
                        items.append(withPresentationRole(presented, role))
                    }
                }
            }
        }
        return items
    }

    private func withPresentationRole(
        _ item: CombatFeedbackItem,
        _ role: CombatFeedbackPresentationRole
    ) -> CombatFeedbackItem {
        CombatFeedbackItem(
            id: item.id,
            sourceEventIDs: item.sourceEventIDs,
            actionGroupID: item.actionGroupID,
            presentationIndex: role == .headline ? 0 : 1,
            groupResultCount: role == .headline ? 1 : 4,
            presentationRole: role,
            targetID: item.targetID,
            feedbackClass: item.feedbackClass,
            keyword: item.keyword,
            visualRole: item.visualRole,
            label: item.label,
            availableAt: item.availableAt,
            expiresAt: item.expiresAt,
            reactionKind: item.reactionKind
        )
    }
}
