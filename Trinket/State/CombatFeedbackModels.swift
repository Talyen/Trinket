import Foundation
import TrinketCore
import TrinketDesignSystem

/// View-facing combat feedback item produced from one or more `ActionEvent`s.
struct CombatFeedbackItem: Identifiable, Equatable {
    let id: Int
    let sourceEventIDs: [Int]
    let actionGroupID: Int
    let presentationIndex: Int
    let groupResultCount: Int
    let targetID: String
    let feedbackClass: CombatFeedbackClass
    let keyword: Keyword
    let label: CombatFeedbackChipLabel
    let secondaryText: String?
    let spawnSeed: Int
    let lifetime: TimeInterval
    let availableAt: Date
    let expiresAt: Date
    let reactionKind: CombatantHitReactionKind

    /// Derived display string for tests, accessibility, and debug tooling.
    var text: String {
        label.displayString
    }
}

/// Card hit-reaction trigger published alongside feedback items.
struct CombatantHitReaction: Equatable {
    let id: Int
    let kind: CombatantHitReactionKind
    let keyword: Keyword
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
