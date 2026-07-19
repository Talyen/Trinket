import Foundation
import TrinketCore
import TrinketDesignSystem

/// Assigns presentation roles for per-target chip groups after same-kind consolidate.
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

    /// One chip per consolidated source. Lane queues own density — no overflow collapse.
    static func makeItems(
        from sorted: [Source],
        actionGroupID: Int,
        availableAt: Date,
        expiresAt: Date
    ) -> [CombatFeedbackItem] {
        let groupResultCount = sorted.count
        return sorted.enumerated().map { presentationIndex, preparedEvent in
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
            reactionKind: prepared.reactionKind,
            lane: .middle
        )
    }
}
