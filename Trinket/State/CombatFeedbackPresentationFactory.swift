import Foundation
import TrinketCore
import TrinketDesignSystem

/// Caps dense per-target chip groups and assigns presentation roles / overflow.
enum CombatFeedbackPresentationFactory {
    struct Source: Equatable {
        let id: Int
        let sourceEventIDs: [Int]
        let targetID: String
        let feedbackClass: CombatFeedbackClass
        let keyword: Keyword
        let visualRole: CombatFeedbackVisualRole
        let label: CombatFeedbackChipLabel
        let secondaryText: String?
        let reactionKind: CombatantHitReactionKind
    }

    /// Caps dense resolves at `maxVisibleIndividualChips` plus one overflow chip.
    static func makeItems(
        from sorted: [Source],
        actionGroupID: Int,
        availableAt: Date,
        expiresAt: Date
    ) -> [CombatFeedbackItem] {
        let maxIndividual = CombatFeedbackLayout.maxVisibleIndividualChips
        let visibleEvents: [Source]
        let overflowCount: Int
        if sorted.count > maxIndividual {
            visibleEvents = Array(sorted.prefix(maxIndividual))
            overflowCount = sorted.count - maxIndividual
        } else {
            visibleEvents = sorted
            overflowCount = 0
        }
        let groupResultCount = visibleEvents.count + (overflowCount > 0 ? 1 : 0)
        var items = visibleEvents.enumerated().map { presentationIndex, preparedEvent in
            makeItem(
                from: preparedEvent,
                actionGroupID: actionGroupID,
                presentationIndex: presentationIndex,
                groupResultCount: groupResultCount,
                presentationRole: presentationRole(
                    index: presentationIndex,
                    groupResultCount: groupResultCount
                ),
                availableAt: availableAt,
                expiresAt: expiresAt
            )
        }
        if overflowCount > 0, let firstDropped = sorted.dropFirst(maxIndividual).first {
            items.append(
                makeOverflowItem(
                    from: Array(sorted.dropFirst(maxIndividual)),
                    firstDropped: firstDropped,
                    actionGroupID: actionGroupID,
                    presentationIndex: items.count,
                    groupResultCount: groupResultCount,
                    availableAt: availableAt,
                    expiresAt: expiresAt
                )
            )
        }
        return items
    }

    private static func presentationRole(
        index: Int,
        groupResultCount: Int
    ) -> CombatFeedbackPresentationRole {
        // Sparse groups keep headline sizing for every chip.
        if groupResultCount <= 3 {
            return .headline
        }
        return index == 0 ? .headline : .secondary
    }

    private static func makeItem(
        from prepared: Source,
        actionGroupID: Int,
        presentationIndex: Int,
        groupResultCount: Int,
        presentationRole: CombatFeedbackPresentationRole,
        availableAt: Date,
        expiresAt: Date
    ) -> CombatFeedbackItem {
        CombatFeedbackItem(
            id: prepared.id,
            sourceEventIDs: prepared.sourceEventIDs,
            actionGroupID: actionGroupID,
            presentationIndex: presentationIndex,
            groupResultCount: groupResultCount,
            presentationRole: presentationRole,
            targetID: prepared.targetID,
            feedbackClass: prepared.feedbackClass,
            keyword: prepared.keyword,
            visualRole: prepared.visualRole,
            label: prepared.label,
            secondaryText: prepared.secondaryText,
            lifetime: TrinketMotion.Battle.chipDisplayDuration,
            availableAt: availableAt,
            expiresAt: expiresAt,
            reactionKind: prepared.reactionKind
        )
    }

    private static func makeOverflowItem(
        from dropped: [Source],
        firstDropped: Source,
        actionGroupID: Int,
        presentationIndex: Int,
        groupResultCount: Int,
        availableAt: Date,
        expiresAt: Date
    ) -> CombatFeedbackItem {
        CombatFeedbackItem(
            id: firstDropped.id &+ 0x4000_0000,
            sourceEventIDs: dropped.flatMap(\.sourceEventIDs),
            actionGroupID: actionGroupID,
            presentationIndex: presentationIndex,
            groupResultCount: groupResultCount,
            presentationRole: .overflow,
            targetID: firstDropped.targetID,
            feedbackClass: .buff,
            keyword: firstDropped.keyword,
            visualRole: .keyword,
            label: .overflow(dropped.count),
            secondaryText: nil,
            lifetime: TrinketMotion.Battle.chipDisplayDuration,
            availableAt: availableAt,
            expiresAt: expiresAt,
            reactionKind: .none
        )
    }
}
