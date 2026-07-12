import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem

/// View-facing combat feedback item produced from one or more `ActionEvent`s.
struct CombatFeedbackItem: Identifiable, Equatable {
    let id: Int
    let targetID: String
    let feedbackClass: CombatFeedbackClass
    let keyword: Keyword
    let text: String
    let secondaryText: String?
    let spawnSeed: Int
    let lifetime: TimeInterval
    let availableAt: Date
    let expiresAt: Date
    let reactionKind: CombatantHitReactionKind

    var recipe: CombatFeedbackMotionRecipe {
        TrinketMotion.Battle.chip(for: feedbackClass)
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

/// Pure presenter: engine events → classified feedback items.
enum CombatFeedbackPresenter {
    static func makeItems(
        from events: [ActionEvent],
        at date: Date,
        stagger: TimeInterval = 0
    ) -> [CombatFeedbackItem] {
        let prepared = mergeCriticals(in: filterDisplayable(events))
        return prepared.enumerated().map { index, preparedEvent in
            let availableAt = date.addingTimeInterval(TimeInterval(index) * stagger)
            return makeItem(from: preparedEvent, availableAt: availableAt)
        }
    }

    static func reaction(for items: [CombatFeedbackItem]) -> CombatantHitReaction? {
        guard let item = items.first(where: { $0.reactionKind != .none })
            ?? items.first else { return nil }
        guard item.reactionKind != .none else { return nil }
        return CombatantHitReaction(
            id: item.id,
            kind: item.reactionKind,
            keyword: item.keyword
        )
    }

    static func bursts(for items: [CombatFeedbackItem]) -> [KeywordBurstRequest] {
        items.compactMap { item in
            let count = CombatFeedbackLayout.particleCount(for: item.feedbackClass)
            guard count > 0 else { return nil }
            return KeywordBurstRequest(
                id: item.id,
                keyword: item.keyword,
                particleCount: count,
                seed: item.spawnSeed,
                availableAt: item.availableAt,
                expiresAt: item.availableAt.addingTimeInterval(0.45)
            )
        }
    }

    // MARK: - Private

    private struct PreparedEvent: Equatable {
        let id: Int
        let targetID: String
        let feedbackClass: CombatFeedbackClass
        let keyword: Keyword
        let text: String
        let secondaryText: String?
        let reactionKind: CombatantHitReactionKind
    }

    private static func filterDisplayable(_ events: [ActionEvent]) -> [ActionEvent] {
        events.filter { event in
            guard event.kind != .milestone else { return false }
            if event.kind == .ability, event.amount == 0 {
                return false
            }
            return true
        }
    }

    private static func mergeCriticals(in events: [ActionEvent]) -> [PreparedEvent] {
        var criticalTargets: Set<String> = []
        for event in events where event.effectKind == .criticalApplied {
            criticalTargets.insert(event.targetID)
        }

        var consumedCriticalTargets: Set<String> = []
        var result: [PreparedEvent] = []

        for event in events {
            if event.effectKind == .criticalApplied {
                // Prefer merging into the damage chip; drop orphan labels when a damage event exists.
                if criticalTargets.contains(event.targetID),
                   events.contains(where: { isDamageChipCandidate($0) && $0.targetID == event.targetID }) {
                    continue
                }
                result.append(prepare(event, forceCritical: false))
                continue
            }

            if isDamageChipCandidate(event),
               criticalTargets.contains(event.targetID),
               !consumedCriticalTargets.contains(event.targetID) {
                consumedCriticalTargets.insert(event.targetID)
                result.append(prepare(event, forceCritical: true))
                continue
            }

            result.append(prepare(event, forceCritical: false))
        }

        return result
    }

    private static func isDamageChipCandidate(_ event: ActionEvent) -> Bool {
        if event.kind == .ability, event.amount > 0 {
            return true
        }
        guard event.kind == .effect else { return false }
        switch event.effectKind {
        case .thornsTriggered, .markedConsumed:
            return event.amount > 0
        default:
            return false
        }
    }

    private static func prepare(_ event: ActionEvent, forceCritical: Bool) -> PreparedEvent {
        let display = ActionEventFormatter.display(for: event)
        let feedbackClass = forceCritical ? .critical : classify(event, display: display)
        let secondary: String? = {
            if forceCritical || feedbackClass == .critical {
                return "CRIT"
            }
            return display.secondaryText
        }()
        return PreparedEvent(
            id: event.id,
            targetID: event.targetID,
            feedbackClass: feedbackClass,
            keyword: display.keyword,
            text: display.text,
            secondaryText: secondary,
            reactionKind: reactionKind(for: feedbackClass)
        )
    }

    private static func makeItem(from prepared: PreparedEvent, availableAt: Date) -> CombatFeedbackItem {
        let recipe = TrinketMotion.Battle.chip(for: prepared.feedbackClass)
        return CombatFeedbackItem(
            id: prepared.id,
            targetID: prepared.targetID,
            feedbackClass: prepared.feedbackClass,
            keyword: prepared.keyword,
            text: prepared.text,
            secondaryText: prepared.secondaryText,
            spawnSeed: prepared.id,
            lifetime: recipe.lifetime,
            availableAt: availableAt,
            expiresAt: availableAt.addingTimeInterval(recipe.lifetime),
            reactionKind: prepared.reactionKind
        )
    }

    private static func classify(
        _ event: ActionEvent,
        display: ActionEventDisplay
    ) -> CombatFeedbackClass {
        switch event.kind {
        case .status:
            return .dot
        case .ability:
            return .directDamage
        case .milestone:
            return .buff
        case .effect:
            break
        }

        switch display.emphasis {
        case .heal:
            return .heal
        case .resourceGain:
            return .resource
        case .shieldAbsorbed:
            return .block
        case .dodge:
            return .dodge
        case .control:
            return .control
        case .deathsDoor:
            return .deathsDoor
        case .status:
            return .dot
        case .damage:
            return .directDamage
        case .buff, .cleanse, .purge, .generic:
            return .buff
        }
    }

    private static func reactionKind(for feedbackClass: CombatFeedbackClass) -> CombatantHitReactionKind {
        switch feedbackClass {
        case .directDamage:
            .damage
        case .dot:
            .none
        case .critical:
            .critical
        case .block:
            .block
        case .heal:
            .heal
        case .dodge:
            .dodge
        case .control, .buff, .resource, .deathsDoor:
            .none
        }
    }
}
