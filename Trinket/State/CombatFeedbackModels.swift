import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem

enum CombatFeedbackVisualRole: Equatable {
    case keyword
    case beneficialStatus
    case negativeStatus

    var cacheKey: String {
        switch self {
        case .keyword: "keyword"
        case .beneficialStatus: "beneficialStatus"
        case .negativeStatus: "negativeStatus"
        }
    }
}

/// View-facing combat feedback item produced from one or more `ActionEvent`s.
struct CombatFeedbackItem: Identifiable, Equatable {
    let id: Int
    let sourceEventIDs: [Int]
    let actionGroupID: Int
    let presentationIndex: Int
    let groupResultCount: Int
    let presentationRole: CombatFeedbackPresentationRole
    let targetID: String
    let feedbackClass: CombatFeedbackClass
    let keyword: Keyword
    let visualRole: CombatFeedbackVisualRole
    let label: CombatFeedbackChipLabel
    let secondaryText: String?
    let lifetime: TimeInterval
    let availableAt: Date
    let expiresAt: Date
    let reactionKind: CombatantHitReactionKind

    /// Derived display string for tests, accessibility, and debug tooling.
    var text: String {
        label.displayString
    }

    func scheduled(at date: Date) -> Self {
        Self(
            id: id,
            sourceEventIDs: sourceEventIDs,
            actionGroupID: actionGroupID,
            presentationIndex: presentationIndex,
            groupResultCount: groupResultCount,
            presentationRole: presentationRole,
            targetID: targetID,
            feedbackClass: feedbackClass,
            keyword: keyword,
            visualRole: visualRole,
            label: label,
            secondaryText: secondaryText,
            lifetime: TrinketMotion.Battle.chipDisplayDuration,
            availableAt: date,
            expiresAt: date.addingTimeInterval(TrinketMotion.Battle.chipDisplayDuration),
            reactionKind: reactionKind
        )
    }
}

/// Incremental battle-to-renderer contract. Normal combat uses insert/remove;
/// replace is reserved for diagnostics that directly seed presentation state.
enum CombatFeedbackUpdate {
    case insert([CombatFeedbackItem])
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

/// Keyword particle burst request for a combatant pane.
struct KeywordBurstRequest: Identifiable, Equatable {
    let id: Int
    let keyword: Keyword
    let particleCount: Int
    let seed: Int
    let availableAt: Date
    let expiresAt: Date
}
