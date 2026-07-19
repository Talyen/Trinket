import Foundation
import TrinketCore
import TrinketDesignSystem

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

    static func closedVocabularyCanvasItems(at date: Date = .now) -> [CombatFeedbackCanvasItem] {
        CombatFeedbackRasterPool.canvasItems(from: closedVocabularyItems(at: date))
    }

    private static func wordSources() -> [CombatFeedbackPresentationFactory.Source] {
        var sources = specialWordSources(startingID: 1)
        sources += keywordWordSources(startingID: sources.count + 1)
        sources += statusWordSources(startingID: sources.count + 1)
        return sources
    }

    private static func specialWordSources(
        startingID: Int
    ) -> [CombatFeedbackPresentationFactory.Source] {
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
            )
        ]
    }

    private static func keywordWordSources(
        startingID: Int
    ) -> [CombatFeedbackPresentationFactory.Source] {
        var sources: [CombatFeedbackPresentationFactory.Source] = []
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
                    )
                ])
                nextID += 3
            }
            sources.append(contentsOf: [
                source(id: nextID, feedbackClass: .buff, keyword: keyword, label: .word(.cleanse(keyword))),
                source(id: nextID + 1, feedbackClass: .buff, keyword: keyword, label: .word(.purge(keyword))),
                source(id: nextID + 2, feedbackClass: .buff, keyword: keyword, label: .word(.halve(keyword)))
            ])
            nextID += 3
        }
        return sources
    }

    private static func statusWordSources(
        startingID: Int
    ) -> [CombatFeedbackPresentationFactory.Source] {
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
    ) -> CombatFeedbackPresentationFactory.Source {
        CombatFeedbackPresentationFactory.Source(
            id: id,
            sourceEventIDs: [id],
            targetID: "catalog",
            feedbackClass: feedbackClass,
            keyword: keyword,
            visualRole: visualRole,
            label: label,
            secondaryText: nil,
            reactionKind: reactionKind
        )
    }

    private static func catalogItem(
        from source: CombatFeedbackPresentationFactory.Source,
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
            sourceEventIDs: source.sourceEventIDs,
            actionGroupID: source.id,
            presentationIndex: presentationRole == .headline ? 0 : 1,
            groupResultCount: presentationRole == .headline ? 1 : 4,
            presentationRole: presentationRole,
            targetID: source.targetID,
            feedbackClass: source.feedbackClass,
            keyword: source.keyword,
            visualRole: source.visualRole,
            label: source.label,
            secondaryText: source.secondaryText,
            lifetime: TrinketMotion.Battle.chipDisplayDuration,
            availableAt: availableAt,
            expiresAt: expiresAt,
            reactionKind: source.reactionKind,
            lane: .middle
        )
    }
}
