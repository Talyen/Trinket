import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

enum CombatFeedbackVisualRole: Equatable {
    case keyword
    case beneficialStatus
    case negativeStatus
}

/// View-facing combat feedback item produced from one or more `ActionEvent`s.
struct CombatFeedbackItem: Identifiable, Equatable {
    let id: Int
    var sourceEventIDs: [Int]
    let actionGroupID: Int
    let presentationIndex: Int
    let groupResultCount: Int
    let presentationRole: CombatFeedbackPresentationRole
    let targetID: String
    let feedbackClass: CombatFeedbackClass
    let keyword: Keyword
    let visualRole: CombatFeedbackVisualRole
    var label: CombatFeedbackChipLabel
    var availableAt: Date
    var expiresAt: Date
    let reactionKind: CombatantHitReactionKind
    var firstScheduledAt: Date

    init(
        id: Int,
        sourceEventIDs: [Int],
        actionGroupID: Int,
        presentationIndex: Int,
        groupResultCount: Int,
        presentationRole: CombatFeedbackPresentationRole,
        targetID: String,
        feedbackClass: CombatFeedbackClass,
        keyword: Keyword,
        visualRole: CombatFeedbackVisualRole,
        label: CombatFeedbackChipLabel,
        availableAt: Date,
        expiresAt: Date,
        reactionKind: CombatantHitReactionKind,
        firstScheduledAt: Date? = nil
    ) {
        self.id = id
        self.sourceEventIDs = sourceEventIDs
        self.actionGroupID = actionGroupID
        self.presentationIndex = presentationIndex
        self.groupResultCount = groupResultCount
        self.presentationRole = presentationRole
        self.targetID = targetID
        self.feedbackClass = feedbackClass
        self.keyword = keyword
        self.visualRole = visualRole
        self.label = label
        self.availableAt = availableAt
        self.expiresAt = expiresAt
        self.reactionKind = reactionKind
        self.firstScheduledAt = firstScheduledAt ?? availableAt
    }

    /// Derived display string for tests and debug tooling.
    var text: String {
        label.displayString
    }

    func scheduled(at date: Date) -> Self {
        var copy = self
        copy.availableAt = date
        copy.expiresAt = date.addingTimeInterval(BattleMotion.chipDisplayDuration)
        copy.firstScheduledAt = date
        return copy
    }
}

/// Incremental battle-to-renderer contract. Normal combat uses insert/remove;
/// replace is reserved for diagnostics that directly seed presentation state.
enum CombatFeedbackUpdate {
    case insert([CombatFeedbackItem])
    case update([CombatFeedbackItem])
    case remove(Set<Int>)
    case replace([CombatFeedbackItem])
    case reset
}

/// Card hit-reaction trigger published alongside feedback items.
struct CombatantHitReaction: Equatable {
    let id: Int
    let kind: CombatantHitReactionKind
}

/// Whole-card attack telegraph published for enemy resolve or party card cast.
struct CombatantAttackReaction: Equatable {
    let id: Int
    let kind: CombatantAttackReactionKind
    let phase: CombatantAttackPhase
}
