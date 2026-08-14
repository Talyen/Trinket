import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

/// Pure presenter: engine events → classified feedback items.
enum CombatFeedbackPresenter {
    static func makeItems(
        from events: [ActionEvent],
        at date: Date
    ) -> [CombatFeedbackItem] {
        let filteredSources = filterDisplayable(events).enumerated().map { order, event in
            PreparedSource(event: event, sourceEventIDs: [event.id], originalOrder: order)
        }
        let sources = consolidate(filteredSources)
        let prepared = sources.compactMap(prepare)
        var targetOrder: [String] = []
        var grouped: [String: [PreparedEvent]] = [:]
        for item in prepared {
            if grouped[item.targetID] == nil {
                targetOrder.append(item.targetID)
            }
            grouped[item.targetID, default: []].append(item)
        }

        return targetOrder.flatMap { targetID -> [CombatFeedbackItem] in
            let sorted = (grouped[targetID] ?? []).sorted { lhs, rhs in
                let lhsPriority = CombatFeedbackClassification.displayPriority(for: lhs.feedbackClass)
                let rhsPriority = CombatFeedbackClassification.displayPriority(for: rhs.feedbackClass)
                if lhsPriority == rhsPriority {
                    return lhs.originalOrder < rhs.originalOrder
                }
                return lhsPriority < rhsPriority
            }
            guard let actionGroupID = sorted.first?.actionID else { return [] }
            let availableAt = date
            let expiresAt = availableAt.addingTimeInterval(TrinketMotion.Battle.chipDisplayDuration)
            let groupResultCount = sorted.count
            return sorted.enumerated().map { presentationIndex, prepared in
                CombatFeedbackItem(
                    id: prepared.id,
                    sourceEventIDs: prepared.sourceEventIDs,
                    actionGroupID: actionGroupID,
                    presentationIndex: presentationIndex,
                    groupResultCount: groupResultCount,
                    presentationRole: presentationRole(
                        index: presentationIndex,
                        groupResultCount: groupResultCount
                    ),
                    targetID: prepared.targetID,
                    feedbackClass: prepared.feedbackClass,
                    keyword: prepared.keyword,
                    visualRole: prepared.visualRole,
                    label: prepared.label,
                    secondaryText: nil,
                    lifetime: TrinketMotion.Battle.chipDisplayDuration,
                    availableAt: availableAt,
                    expiresAt: expiresAt,
                    reactionKind: prepared.reactionKind
                )
            }
        }
    }

    /// Sparse groups keep headline sizing for every chip; denser groups promote index 0.
    private static func presentationRole(
        index: Int,
        groupResultCount: Int
    ) -> CombatFeedbackPresentationRole {
        if groupResultCount <= 3 {
            return .headline
        }
        return index == 0 ? .headline : .secondary
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
        let visualRole: CombatFeedbackVisualRole
        let label: CombatFeedbackChipLabel
        let reactionKind: CombatantHitReactionKind
    }

    private struct AggregationKey: Hashable {
        enum Family: Hashable {
            case abilityDamage
            case status
            case effect(ActionEvent.EffectKind)
        }

        let targetID: String
        let keyword: Keyword
        let family: Family
        let isCritical: Bool
        let isNegative: Bool
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
            if event.effectKind == .cardsDrawn || event.effectKind == .controlApplied {
                return false
            }
            return true
        }
    }

    private static func consolidate(_ sources: [PreparedSource]) -> [PreparedSource] {
        var result: [PreparedSource] = []
        var keyIndices: [AggregationKey: Int] = [:]
        for source in sources {
            guard let key = aggregationKey(for: source.event) else {
                result.append(source)
                continue
            }
            if let index = keyIndices[key] {
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
                keyIndices[key] = result.count
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
            isCritical: event.isCritical,
            isNegative: event.amount < 0
        )
    }

    private static func isAdditive(_ effectKind: ActionEvent.EffectKind) -> Bool {
        switch effectKind {
        case .instantHeal, .resourceGain, .cardsDrawn, .leechHeal, .shieldApplied,
             .shieldAbsorbed, .thornsTriggered, .markedConsumed,
             .manaShieldTriggered:
            true
        default:
            false
        }
    }

    private static func replacingAmount(in event: ActionEvent, with amount: Int) -> ActionEvent {
        event.with(amount: amount)
    }

    private static func prepare(_ source: PreparedSource) -> PreparedEvent? {
        let event = source.event
        let feedbackClass = event.isCritical
            ? .critical
            : CombatFeedbackClassification.classify(event)
        guard let label = CombatFeedbackChipLabel.from(event: event), !label.isZeroNumeric else {
            return nil
        }
        return PreparedEvent(
            id: event.id,
            sourceEventIDs: source.sourceEventIDs,
            originalOrder: source.originalOrder,
            actionID: event.actionID,
            targetID: event.targetID,
            feedbackClass: feedbackClass,
            keyword: event.keyword,
            visualRole: visualRole(for: event, label: label),
            label: label,
            reactionKind: CombatFeedbackClassification.reactionKind(for: feedbackClass)
        )
    }

    private static func visualRole(
        for event: ActionEvent,
        label: CombatFeedbackChipLabel
    ) -> CombatFeedbackVisualRole {
        switch event.effectKind {
        case .thornsApplied, .criticalChanceApplied, .manaShieldApplied,
             .damageKeywordOverrideApplied, .nextHolyStrikeApplied, .nextStrikeDoubleApplied,
             .evadeNextHitApplied, .leechApplied:
            .beneficialStatus
        case .markedApplied, .shieldHalved:
            .negativeStatus
        default:
            label.isNegativeNumeric ? .negativeStatus : .keyword
        }
    }
}
