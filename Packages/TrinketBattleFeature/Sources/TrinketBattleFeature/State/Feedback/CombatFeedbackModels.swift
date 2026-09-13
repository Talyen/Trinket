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

struct CombatFeedbackItem: Identifiable, Equatable {
    let id: Int
    var sourceEventIDs: [Int]
    let actionGroupID: Int
    let presentationIndex: Int
    let targetID: String
    let feedbackClass: CombatFeedbackClass
    let keyword: Keyword
    let visualRole: CombatFeedbackVisualRole
    var label: CombatFeedbackChipLabel
    var availableAt: Date
    var expiresAt: Date
    let reactionKind: CombatantHitReactionKind
    var firstScheduledAt: Date
    var lastUpdatedAt: Date?
    var retiringAt: Date?
    var isCritical: Bool
    var criticalAt: Date?

    init(
        id: Int,
        sourceEventIDs: [Int],
        actionGroupID: Int,
        presentationIndex: Int,
        targetID: String,
        feedbackClass: CombatFeedbackClass,
        keyword: Keyword,
        visualRole: CombatFeedbackVisualRole,
        label: CombatFeedbackChipLabel,
        availableAt: Date,
        expiresAt: Date,
        reactionKind: CombatantHitReactionKind,
        firstScheduledAt: Date? = nil,
        isCritical: Bool = false,
    ) {
        self.id = id
        self.sourceEventIDs = sourceEventIDs
        self.actionGroupID = actionGroupID
        self.presentationIndex = presentationIndex
        self.targetID = targetID
        self.feedbackClass = feedbackClass
        self.keyword = keyword
        self.visualRole = visualRole
        self.label = label
        self.availableAt = availableAt
        self.expiresAt = expiresAt
        self.reactionKind = reactionKind
        self.firstScheduledAt = firstScheduledAt ?? availableAt
        self.isCritical = isCritical
        criticalAt = isCritical ? availableAt : nil
    }

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

enum CombatFeedbackUpdate {
    case insert([CombatFeedbackItem])
    case update([CombatFeedbackItem])
    case remove(Set<Int>)
    case replace([CombatFeedbackItem])
    case reset
}

struct CombatantHitReaction: Equatable {
    let id: Int
    let kind: CombatantHitReactionKind
}

struct CombatantAttackReaction: Equatable {
    let id: Int
    let kind: CombatantAttackReactionKind
    let phase: CombatantAttackPhase
}
