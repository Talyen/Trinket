import BattleEngine
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
        let sources = consolidate(mergeCriticals(in: filterDisplayable(events)))
        let prepared = sources.map(prepare)
        var targetOrder: [String] = []
        var grouped: [String: [PreparedEvent]] = [:]
        for item in prepared {
            if grouped[item.targetID] == nil {
                targetOrder.append(item.targetID)
            }
            grouped[item.targetID, default: []].append(item)
        }

        return targetOrder.enumerated().flatMap { groupIndex, targetID -> [CombatFeedbackItem] in
            let sorted = (grouped[targetID] ?? []).sorted { lhs, rhs in
                let lhsPriority = displayPriority(for: lhs.feedbackClass)
                let rhsPriority = displayPriority(for: rhs.feedbackClass)
                if lhsPriority == rhsPriority {
                    return lhs.originalOrder < rhs.originalOrder
                }
                return lhsPriority < rhsPriority
            }
            guard let actionGroupID = sorted.flatMap(\.sourceEventIDs).min() else { return [] }
            let availableAt = date.addingTimeInterval(TimeInterval(groupIndex) * stagger)
            let groupLifetime = sorted
                .map { TrinketMotion.Battle.chip(for: $0.feedbackClass).lifetime }
                .max() ?? 0
            let expiresAt = availableAt.addingTimeInterval(groupLifetime)
            return sorted.enumerated().map { presentationIndex, preparedEvent in
                makeItem(
                    from: preparedEvent,
                    actionGroupID: actionGroupID,
                    presentationIndex: presentationIndex,
                    groupResultCount: sorted.count,
                    availableAt: availableAt,
                    expiresAt: expiresAt
                )
            }
        }
    }

    static func reaction(for items: [CombatFeedbackItem]) -> CombatantHitReaction? {
        guard let item = items.first(where: {
            $0.presentationIndex == 0 && $0.reactionKind != .none
        }) else { return nil }
        guard item.reactionKind != .none else { return nil }
        return CombatantHitReaction(
            id: item.id,
            kind: item.reactionKind,
            keyword: item.keyword
        )
    }

    static func bursts(for items: [CombatFeedbackItem]) -> [KeywordBurstRequest] {
        items.compactMap { item in
            guard item.presentationIndex < 3 else { return nil }
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

    private struct PreparedSource: Equatable {
        var event: ActionEvent
        var forceCritical: Bool
        var sourceEventIDs: [Int]
        let originalOrder: Int
    }

    private struct PreparedEvent: Equatable {
        let id: Int
        let sourceEventIDs: [Int]
        let originalOrder: Int
        let targetID: String
        let feedbackClass: CombatFeedbackClass
        let keyword: Keyword
        let text: String
        let secondaryText: String?
        let reactionKind: CombatantHitReactionKind
    }

    private struct AggregationKey: Equatable {
        enum Family: Equatable {
            case ability
            case status
            case effect(ActionEvent.EffectKind)
        }

        let targetID: String
        let keyword: Keyword
        let family: Family
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

    private static func mergeCriticals(in events: [ActionEvent]) -> [PreparedSource] {
        let criticalsByTarget = Dictionary(grouping: events.filter {
            $0.effectKind == .criticalApplied
        }, by: \.targetID)
        var consumedCriticalIDs: Set<Int> = []
        var result: [PreparedSource] = []

        for (originalOrder, event) in events.enumerated() {
            if event.effectKind == .criticalApplied {
                // Prefer merging into the damage chip; drop orphan labels when a damage event exists.
                if events.contains(where: { isDamageChipCandidate($0) && $0.targetID == event.targetID }) {
                    continue
                }
                result.append(PreparedSource(
                    event: event,
                    forceCritical: false,
                    sourceEventIDs: [event.id],
                    originalOrder: originalOrder
                ))
                continue
            }

            var sourceEventIDs = [event.id]
            var forceCritical = false
            if isDamageChipCandidate(event),
               let critical = criticalsByTarget[event.targetID]?.first(where: {
                   !consumedCriticalIDs.contains($0.id)
               }) {
                consumedCriticalIDs.insert(critical.id)
                sourceEventIDs.append(critical.id)
                forceCritical = true
            }
            result.append(PreparedSource(
                event: event,
                forceCritical: forceCritical,
                sourceEventIDs: sourceEventIDs,
                originalOrder: originalOrder
            ))
        }

        return result
    }

    private static func consolidate(_ sources: [PreparedSource]) -> [PreparedSource] {
        var result: [PreparedSource] = []
        for source in sources {
            guard let key = aggregationKey(for: source.event) else {
                result.append(source)
                continue
            }
            if let index = result.firstIndex(where: {
                aggregationKey(for: $0.event) == key
            }) {
                let existing = result[index]
                result[index] = PreparedSource(
                    event: replacingAmount(
                        in: existing.event,
                        with: existing.event.amount + source.event.amount
                    ),
                    forceCritical: existing.forceCritical || source.forceCritical,
                    sourceEventIDs: existing.sourceEventIDs + source.sourceEventIDs,
                    originalOrder: min(existing.originalOrder, source.originalOrder)
                )
            } else {
                result.append(source)
            }
        }
        return result
    }

    private static func aggregationKey(for event: ActionEvent) -> AggregationKey? {
        let family: AggregationKey.Family
        switch event.kind {
        case .ability:
            family = .ability
        case .status:
            family = .status
        case .effect:
            guard let effectKind = event.effectKind, isAdditive(effectKind) else { return nil }
            family = .effect(effectKind)
        case .milestone:
            return nil
        }
        return AggregationKey(targetID: event.targetID, keyword: event.keyword, family: family)
    }

    private static func isAdditive(_ effectKind: ActionEvent.EffectKind) -> Bool {
        switch effectKind {
        case .instantHeal, .resourceGain, .cardsDrawn, .leechHeal, .shieldAbsorbed,
             .thornsTriggered, .markedConsumed, .manaShieldTriggered:
            true
        default:
            false
        }
    }

    private static func replacingAmount(in event: ActionEvent, with amount: Int) -> ActionEvent {
        ActionEvent(
            id: event.id,
            kind: event.kind,
            effectKind: event.effectKind,
            actorID: event.actorID,
            actorName: event.actorName,
            abilityID: event.abilityID,
            abilityName: event.abilityName,
            abilityTier: event.abilityTier,
            targetID: event.targetID,
            targetName: event.targetName,
            amount: amount,
            keyword: event.keyword,
            appliedEffectSummaries: event.appliedEffectSummaries,
            milestone: event.milestone
        )
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

    private static func prepare(_ source: PreparedSource) -> PreparedEvent {
        let event = source.event
        let display = ActionEventFormatter.display(for: event)
        let feedbackClass = source.forceCritical ? .critical : classify(event, display: display)
        let secondary: String? = {
            if source.forceCritical || feedbackClass == .critical {
                return "CRIT"
            }
            return display.secondaryText
        }()
        return PreparedEvent(
            id: event.id,
            sourceEventIDs: source.sourceEventIDs,
            originalOrder: source.originalOrder,
            targetID: event.targetID,
            feedbackClass: feedbackClass,
            keyword: display.keyword,
            text: display.text,
            secondaryText: secondary,
            reactionKind: reactionKind(for: feedbackClass)
        )
    }

    private static func makeItem(
        from prepared: PreparedEvent,
        actionGroupID: Int,
        presentationIndex: Int,
        groupResultCount: Int,
        availableAt: Date,
        expiresAt: Date
    ) -> CombatFeedbackItem {
        let recipe = TrinketMotion.Battle.chip(for: prepared.feedbackClass)
        return CombatFeedbackItem(
            id: prepared.id,
            sourceEventIDs: prepared.sourceEventIDs,
            actionGroupID: actionGroupID,
            presentationIndex: presentationIndex,
            groupResultCount: groupResultCount,
            targetID: prepared.targetID,
            feedbackClass: prepared.feedbackClass,
            keyword: prepared.keyword,
            text: prepared.text,
            secondaryText: prepared.secondaryText,
            spawnSeed: prepared.id,
            lifetime: recipe.lifetime,
            availableAt: availableAt,
            expiresAt: expiresAt,
            reactionKind: prepared.reactionKind
        )
    }

    private static func displayPriority(for feedbackClass: CombatFeedbackClass) -> Int {
        switch feedbackClass {
        case .critical: 0
        case .deathsDoor: 1
        case .directDamage: 2
        case .heal: 3
        case .block, .dodge, .control: 4
        case .dot: 5
        case .buff, .resource: 6
        }
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
