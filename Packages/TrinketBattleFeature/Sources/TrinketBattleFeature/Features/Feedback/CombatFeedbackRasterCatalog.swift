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
@MainActor
enum CombatFeedbackRasterCatalog {
    /// Every closed (non-numeric) chip the presenter can emit, in both headline and
    /// secondary roles so dense groups stay cache-warm.
    static func closedVocabularyItems(at date: Date = .now) -> [CombatFeedbackItem] {
        let wordSources = wordSources()
        let expiresAt = date.addingTimeInterval(1)
        var items: [CombatFeedbackItem] = []
        for role in CombatFeedbackPresentationRole.allCases {
            for source in wordSources {
                items.append(
                    catalogItem(
                        from: source,
                        presentationRole: role,
                        availableAt: date,
                        expiresAt: expiresAt
                    )
                )
            }
        }
        return items
    }

    static func closedVocabularyChips(at date: Date = .now) -> [CombatFeedbackItem] {
        // Prepare every action group in the batch — not only the single newest group
        // the overlay keeps on-screen — so staggered targets are warm before availableAt.
        CombatFeedbackOverlayPolicy.orderedChips(from: closedVocabularyItems(at: date))
    }

    private struct CatalogSource {
        let id: Int
        let feedbackClass: CombatFeedbackClass
        let keyword: Keyword
        let visualRole: CombatFeedbackVisualRole
        let label: CombatFeedbackChipLabel
        let reactionKind: CombatantHitReactionKind
    }

    private static func wordSources() -> [CatalogSource] {
        var sources = specialWordSources(startingID: 1)
        sources += keywordWordSources(startingID: sources.count + 1)
        sources += statusWordSources(startingID: sources.count + 1)
        return sources
    }

    private static func specialWordSources(startingID: Int) -> [CatalogSource] {
        [
            source(
                id: startingID,
                feedbackClass: .dodge,
                keyword: .dodge,
                visualRole: .keyword,
                label: .word(.dodge),
                reactionKind: .dodge
            ),
            source(
                id: startingID + 1,
                feedbackClass: .critical,
                keyword: .physical,
                visualRole: .keyword,
                label: .word(.critical),
                reactionKind: .critical
            ),
            source(
                id: startingID + 2,
                feedbackClass: .deathsDoor,
                keyword: .deathsDoor,
                visualRole: .keyword,
                label: .word(.plain(.deathsDoor))
            ),
        ]
    }

    private static func keywordWordSources(startingID: Int) -> [CatalogSource] {
        var sources: [CatalogSource] = []
        var nextID = startingID
        for keyword in Keyword.allCases {
            if keyword != .deathsDoor {
                sources.append(contentsOf: [
                    source(id: nextID, feedbackClass: .buff, keyword: keyword, label: .word(.plain(keyword))),
                    source(
                        id: nextID + 1,
                        feedbackClass: .buff,
                        keyword: keyword,
                        label: .word(.applied(keyword))
                    ),
                    source(
                        id: nextID + 2,
                        feedbackClass: .buff,
                        keyword: keyword,
                        label: .word(.triggered(keyword))
                    ),
                ])
                nextID += 3
            }
            sources.append(contentsOf: [
                source(id: nextID, feedbackClass: .buff, keyword: keyword, label: .word(.cleanse(keyword))),
                source(id: nextID + 1, feedbackClass: .buff, keyword: keyword, label: .word(.purge(keyword))),
            ])
            nextID += 2
        }
        return sources
    }

    private static func statusWordSources(startingID: Int) -> [CatalogSource] {
        CombatFeedbackStatusLabel.allCases.enumerated().map { offset, status in
            source(
                id: startingID + offset,
                feedbackClass: .buff,
                keyword: .holy,
                visualRole: .beneficialStatus,
                label: .word(.status(status))
            )
        }
    }

    private static func source(
        id: Int,
        feedbackClass: CombatFeedbackClass,
        keyword: Keyword,
        visualRole: CombatFeedbackVisualRole = .keyword,
        label: CombatFeedbackChipLabel,
        reactionKind: CombatantHitReactionKind = .none
    ) -> CatalogSource {
        CatalogSource(
            id: id,
            feedbackClass: feedbackClass,
            keyword: keyword,
            visualRole: visualRole,
            label: label,
            reactionKind: reactionKind
        )
    }

    private static func catalogItem(
        from source: CatalogSource,
        presentationRole: CombatFeedbackPresentationRole,
        availableAt: Date,
        expiresAt: Date
    ) -> CombatFeedbackItem {
        let roleBias = switch presentationRole {
        case .headline: 0
        case .secondary: 0x1000_0000
        }
        return CombatFeedbackItem(
            id: source.id &+ roleBias,
            sourceEventIDs: [source.id],
            actionGroupID: source.id,
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
            reactionKind: source.reactionKind
        )
    }
}
