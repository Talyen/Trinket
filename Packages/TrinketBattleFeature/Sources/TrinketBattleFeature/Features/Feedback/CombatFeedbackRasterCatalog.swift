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
        let expiresAt = date.addingTimeInterval(1)
        var items: [CombatFeedbackItem] = []
        var preparedAppearances: Set<PreparedAppearance> = []
        var nextID = 1
        for source in liveWordSources {
            for role in CombatFeedbackPresentationRole.allCases {
                let item = catalogItem(
                    from: source,
                    id: nextID,
                    presentationRole: role,
                    availableAt: date,
                    expiresAt: expiresAt
                )
                let appearance = PreparedAppearance(
                    typography: item.feedbackClass.typographyTier,
                    presentationRole: role,
                    presentation: item.chipPresentation
                )
                if preparedAppearances.insert(appearance).inserted {
                    items.append(item)
                    nextID += 1
                }
            }
        }
        return items
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

    private struct CatalogSource {
        let feedbackClass: CombatFeedbackClass
        let keyword: Keyword
        let visualRole: CombatFeedbackVisualRole
        let label: CombatFeedbackChipLabel
    }

    private struct PreparedAppearance: Hashable {
        let typography: CombatFeedbackTypographyTier
        let presentationRole: CombatFeedbackPresentationRole
        let presentation: CombatFeedbackChipPresentation
    }

    private struct ResolvedAppearance: Hashable {
        let typography: CombatFeedbackTypographyTier
        let presentation: CombatFeedbackChipPresentation
    }

    /// Presenter enumeration is independent of chip dates/roles; share one result
    /// across catalog warmup and glyph-atlas fragment collection.
    private static let liveWordSources: [CatalogSource] = {
        var sources: [CatalogSource] = []
        for outcome in ActionEvent.EffectOutcome.allCases {
            let descriptor = CombatFeedbackEffectPresentation.descriptor(for: outcome)
            guard descriptor.shouldDisplay(amount: 1), isClosedVocabulary(descriptor) else {
                continue
            }
            var seenAppearances: Set<ResolvedAppearance> = []
            for keyword in Keyword.allCases {
                let event = catalogEvent(outcome: outcome, keyword: keyword)
                for item in CombatFeedbackPresenter.makeItems(
                    from: [event],
                    at: Date(timeIntervalSince1970: 0)
                ) {
                    let appearance = ResolvedAppearance(
                        typography: item.feedbackClass.typographyTier,
                        presentation: item.chipPresentation
                    )
                    guard seenAppearances.insert(appearance).inserted else { continue }
                    sources.append(
                        CatalogSource(
                            feedbackClass: item.feedbackClass,
                            keyword: item.keyword,
                            visualRole: item.visualRole,
                            label: item.label
                        )
                    )
                }
            }
        }
        return sources
    }()

    private static func isClosedVocabulary(
        _ descriptor: CombatFeedbackEffectPresentation.Descriptor
    ) -> Bool {
        if descriptor.statusLabel != nil {
            return true
        }
        switch descriptor.labelRule {
        case .dodgeWord, .plainKeyword, .appliedKeyword, .triggeredKeyword,
             .cleanseKeyword, .purgeKeyword, .deathsDoorIcon:
            return true
        case .amount, .negatedAmount, nil:
            return false
        }
    }

    private static func catalogEvent(
        outcome: ActionEvent.EffectOutcome,
        keyword: Keyword
    ) -> ActionEvent {
        ActionEvent(
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
    }

    private static func catalogItem(
        from source: CatalogSource,
        id: Int,
        presentationRole: CombatFeedbackPresentationRole,
        availableAt: Date,
        expiresAt: Date
    ) -> CombatFeedbackItem {
        CombatFeedbackItem(
            id: id,
            sourceEventIDs: [id],
            actionGroupID: id,
            presentationIndex: presentationRole == .headline ? 0 : 1,
            groupResultCount: presentationRole == .headline ? 1 : 4,
            presentationRole: presentationRole,
            targetID: "catalog",
            feedbackClass: source.feedbackClass,
            keyword: source.keyword,
            visualRole: source.visualRole,
            label: source.label,
            availableAt: availableAt,
            expiresAt: expiresAt,
            reactionKind: .none
        )
    }
}
