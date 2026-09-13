import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

enum CombatFeedbackPresenter {
    private static func displayPriority(for feedbackClass: CombatFeedbackClass) -> Int {
        switch feedbackClass {
        case .critical: 0
        case .deathsDoor: 1
        case .block, .dodge, .control: 2
        case .directDamage, .dot: 3
        case .heal: 4
        case .buff, .resource: 6
        }
    }

    private static func classify(_ event: ActionEvent) -> CombatFeedbackClass {
        switch event.kind {
        case .abilityDamage:
            return .directDamage
        case .status:
            return .directDamage
        case .ability, .milestone:
            return .buff
        case .effect:
            guard let effectKind = event.effectKind else { return .buff }
            return CombatFeedbackEffectPresentation.descriptor(for: effectKind).feedbackClass
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

    static func makeItems(
        from events: [ActionEvent],
        at date: Date,
    ) -> [CombatFeedbackItem] {
        let filteredSources = filterDisplayable(events).enumerated().map { order, event in
            PreparedSource(event: event, sourceEventIDs: [event.id], originalOrder: order)
        }
        let sources = consolidate(filteredSources)
        let prepared = sources.compactMap(prepare)
        var groupOrder: [PresentationGroupKey] = []
        var grouped: [PresentationGroupKey: [PreparedEvent]] = [:]
        for item in prepared {
            let key = PresentationGroupKey(actionID: item.actionID, targetID: item.targetID)
            if grouped[key] == nil {
                groupOrder.append(key)
            }
            grouped[key, default: []].append(item)
        }

        return groupOrder.flatMap { key -> [CombatFeedbackItem] in
            let sorted = (grouped[key] ?? []).sorted { lhs, rhs in
                let lhsPriority = displayPriority(for: lhs.feedbackClass)
                let rhsPriority = displayPriority(for: rhs.feedbackClass)
                if lhsPriority == rhsPriority {
                    return lhs.originalOrder < rhs.originalOrder
                }
                return lhsPriority < rhsPriority
            }
            let availableAt = date
            let expiresAt = availableAt.addingTimeInterval(BattleMotion.chipDisplayDuration)
            return sorted.enumerated().map { presentationIndex, prepared in
                CombatFeedbackItem(
                    id: prepared.id,
                    sourceEventIDs: prepared.sourceEventIDs,
                    actionGroupID: key.actionID,
                    presentationIndex: presentationIndex,
                    targetID: prepared.targetID,
                    feedbackClass: prepared.feedbackClass,
                    keyword: prepared.keyword,
                    visualRole: prepared.visualRole,
                    label: prepared.label,
                    availableAt: availableAt,
                    expiresAt: expiresAt,
                    reactionKind: prepared.reactionKind,
                    isCritical: prepared.isCritical,
                )
            }
        }
    }

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
        let isCritical: Bool
    }

    private struct AggregationKey: Hashable {
        enum Family: Hashable {
            case abilityDamage
            case effect(ActionEvent.EffectOutcome)
        }

        let actionID: Int
        let targetID: String
        let keyword: Keyword
        let family: Family
        let isNegative: Bool
    }

    private struct PresentationGroupKey: Hashable {
        let actionID: Int
        let targetID: String
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
            if event.kind == .effect, let effectKind = event.effectKind {
                if effectKind == .shieldAbsorbed {
                    return event.isFullyBlocked
                }
                if effectKind == .recurringDamageApplied || effectKind == .dotAmplified {
                    return false
                }
                let feedbackClass = classify(event)
                if feedbackClass == .buff || feedbackClass == .resource, event.origin != .direct {
                    return false
                }
                return CombatFeedbackEffectPresentation
                    .descriptor(for: effectKind)
                    .shouldDisplay(amount: event.amount)
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
                    event: existing.event.with(
                        amount: existing.event.amount + source.event.amount,
                        isCritical: existing.event.isCritical || source.event.isCritical,
                    ),
                    sourceEventIDs: existing.sourceEventIDs + source.sourceEventIDs,
                    originalOrder: min(existing.originalOrder, source.originalOrder),
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
        case .status:
            family = .abilityDamage
        case .effect:
            guard let effectKind = event.effectKind,
                  CombatFeedbackEffectPresentation.descriptor(for: effectKind).isAdditive
            else { return nil }
            switch classify(event) {
            case .directDamage: family = .abilityDamage
            case .heal: family = .effect(.instantHeal)
            default: family = .effect(effectKind)
            }
        case .ability, .milestone:
            return nil
        }
        return AggregationKey(
            actionID: event.feedbackGroupID,
            targetID: event.targetID,
            keyword: classify(event) == .heal ? .health : event.keyword,
            family: family,
            isNegative: event.amount < 0,
        )
    }

    private static func prepare(_ source: PreparedSource) -> PreparedEvent? {
        let event = source.event
        let feedbackClass = classify(event)
        guard let label = CombatFeedbackChipLabel.from(event: event), !label.isZeroNumeric else {
            return nil
        }
        return PreparedEvent(
            id: event.id,
            sourceEventIDs: source.sourceEventIDs,
            originalOrder: source.originalOrder,
            actionID: event.feedbackGroupID,
            targetID: event.targetID,
            feedbackClass: feedbackClass,
            keyword: feedbackClass == .heal ? .health : event.keyword,
            visualRole: visualRole(for: event),
            label: label,
            reactionKind: event.kind == .status ? .none : reactionKind(for: feedbackClass),
            isCritical: event.isCritical,
        )
    }

    private static func visualRole(for event: ActionEvent) -> CombatFeedbackVisualRole {
        guard let effectKind = event.effectKind else { return .keyword }
        return CombatFeedbackEffectPresentation.descriptor(for: effectKind).visualRole
    }
}
