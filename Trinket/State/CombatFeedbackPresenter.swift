import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem

/// Pure presenter: engine events → classified feedback items.
enum CombatFeedbackPresenter {
    static func makeItems(
        from events: [ActionEvent],
        at date: Date,
        stagger: TimeInterval = 0
    ) -> [CombatFeedbackItem] {
        let sources = consolidate(filterDisplayable(events).enumerated().map { order, event in
            PreparedSource(event: event, sourceEventIDs: [event.id], originalOrder: order)
        })
        let prepared = sources.compactMap(prepare)
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
                let lhsPriority = CombatFeedbackClassification.displayPriority(for: lhs.feedbackClass)
                let rhsPriority = CombatFeedbackClassification.displayPriority(for: rhs.feedbackClass)
                if lhsPriority == rhsPriority {
                    return lhs.originalOrder < rhs.originalOrder
                }
                return lhsPriority < rhsPriority
            }
            guard let actionGroupID = sorted.first?.actionID else { return [] }
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
        var sourceEventIDs: [Int]
        let originalOrder: Int
    }

    private struct PreparedEvent: Equatable {
        let id: Int
        let sourceEventIDs: [Int]
        let originalOrder: Int
        let actionID: Int
        let targetID: String
        let feedbackClass: CombatFeedbackClass
        let keyword: Keyword
        let label: CombatFeedbackChipLabel
        let secondaryText: String?
        let reactionKind: CombatantHitReactionKind
    }

    private struct AggregationKey: Equatable {
        enum Family: Equatable {
            case abilityDamage
            case status
            case effect(ActionEvent.EffectKind)
        }

        let targetID: String
        let keyword: Keyword
        let family: Family
        let isCritical: Bool
    }

    private static func filterDisplayable(_ events: [ActionEvent]) -> [ActionEvent] {
        events.filter { event in
            guard event.kind != .milestone else { return false }
            if event.kind == .ability {
                return false
            }
            if event.kind == .abilityDamage, event.amount == 0 {
                return false
            }
            return true
        }
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
        case .abilityDamage:
            family = .abilityDamage
        case .ability:
            return nil
        case .status:
            family = .status
        case .effect:
            guard let effectKind = event.effectKind, isAdditive(effectKind) else { return nil }
            family = .effect(effectKind)
        case .milestone:
            return nil
        }
        return AggregationKey(
            targetID: event.targetID,
            keyword: event.keyword,
            family: family,
            isCritical: event.isCritical
        )
    }

    private static func isAdditive(_ effectKind: ActionEvent.EffectKind) -> Bool {
        switch effectKind {
        case .instantHeal, .resourceGain, .cardsDrawn, .leechHeal, .shieldApplied,
             .mitigationApplied, .shieldAbsorbed, .thornsTriggered, .markedConsumed,
             .manaShieldTriggered:
            true
        default:
            false
        }
    }

    private static func replacingAmount(in event: ActionEvent, with amount: Int) -> ActionEvent {
        ActionEvent(
            id: event.id,
            actionID: event.actionID,
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
            milestone: event.milestone,
            isCritical: event.isCritical
        )
    }

    private static func prepare(_ source: PreparedSource) -> PreparedEvent? {
        let event = source.event
        let display = ActionEventFormatter.display(for: event)
        let feedbackClass = event.isCritical
            ? .critical
            : CombatFeedbackClassification.classify(event, display: display)
        let floatingText = Self.floatingText(from: display)
        guard let label = CombatFeedbackChipLabel.fromDisplayText(floatingText) else {
            return nil
        }
        return PreparedEvent(
            id: event.id,
            sourceEventIDs: source.sourceEventIDs,
            originalOrder: source.originalOrder,
            actionID: event.actionID,
            targetID: event.targetID,
            feedbackClass: feedbackClass,
            keyword: display.keyword,
            label: label,
            secondaryText: display.secondaryText,
            reactionKind: CombatFeedbackClassification.reactionKind(for: feedbackClass)
        )
    }

    /// Numeric effects use the icon for their keyword identity, so the float only
    /// needs the signed amount (and any attached numeric unit such as `%`).
    /// Text-only effects retain their descriptive label, such as "Dodge".
    private static func floatingText(from display: ActionEventDisplay) -> String {
        guard let firstToken = display.text.split(separator: " ").first,
              firstToken.contains(where: \.isNumber) else {
            return display.text
        }
        return String(firstToken)
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
            label: prepared.label,
            secondaryText: prepared.secondaryText,
            spawnSeed: prepared.id,
            lifetime: recipe.lifetime,
            availableAt: availableAt,
            expiresAt: expiresAt,
            reactionKind: prepared.reactionKind
        )
    }
}
