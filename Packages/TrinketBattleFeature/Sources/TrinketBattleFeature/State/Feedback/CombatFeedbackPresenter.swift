import BattleEngine
import Foundation
import TrinketContent
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
        case .abilityDamage, .status:
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
        actionGroupID: Int? = nil,
    ) -> [CombatFeedbackItem] {
        let filteredSources = filterDisplayable(events).enumerated().map { order, event in
            PreparedSource(event: event, sourceEventIDs: [event.id], originalOrder: order)
        }
        var groupOrder: [PresentationGroupKey] = []
        var grouped: [
            PresentationGroupKey: [(source: PreparedSource, label: CombatFeedbackChipLabel, feedbackClass: CombatFeedbackClass)]
        ] =
            [:]
        for source in consolidate(filteredSources) {
            guard let label = CombatFeedbackChipLabel.from(event: source.event), !label.isZeroNumeric else { continue }
            let key = PresentationGroupKey(actionID: actionGroupID ?? source.event.feedbackGroupID, targetID: source.event.targetID)
            if grouped[key] == nil {
                groupOrder.append(key)
            }
            grouped[key, default: []].append((source, label, classify(source.event)))
        }

        return groupOrder.flatMap { key -> [CombatFeedbackItem] in
            let sorted = (grouped[key] ?? []).sorted { lhs, rhs in
                let lhsPriority = displayPriority(for: lhs.feedbackClass)
                let rhsPriority = displayPriority(for: rhs.feedbackClass)
                if lhsPriority == rhsPriority {
                    return lhs.source.originalOrder < rhs.source.originalOrder
                }
                return lhsPriority < rhsPriority
            }
            return sorted.enumerated().map { presentationIndex, item in
                let event = item.source.event
                let feedbackClass = item.feedbackClass
                return CombatFeedbackItem(
                    id: event.id,
                    sourceEventIDs: item.source.sourceEventIDs,
                    actionGroupID: key.actionID,
                    presentationIndex: presentationIndex,
                    targetID: event.targetID,
                    feedbackClass: feedbackClass,
                    keyword: feedbackClass == .heal ? .health : event.keyword,
                    visualRole: visualRole(for: event),
                    label: item.label,
                    availableAt: date,
                    expiresAt: date.addingTimeInterval(BattleMotion.chipDisplayDuration),
                    reactionKind: event.kind == .status || event.origin == .periodic ? .none : reactionKind(for: feedbackClass),
                    isCritical: event.isCritical,
                    effectKind: feedbackClass == .directDamage ? nil : (feedbackClass == .heal ? .instantHeal : event.effectKind),
                )
            }
        }
    }

    private struct PreparedSource: Equatable {
        var event: ActionEvent
        var sourceEventIDs: [Int]
        let originalOrder: Int
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
        let cardSources = Set(events.lazy.filter { $0.kind == .ability }.compactMap(CombatCardSourceKey.init))
        return events.filter { event in
            switch event.kind {
            case .ability, .milestone:
                return false
            case .abilityDamage:
                return event.amount != 0
            case .status:
                return true
            case .effect:
                guard let effectKind = event.effectKind else { return true }
                if effectKind == .controlActionSkipped || effectKind == .controlTriggered,
                   event.keyword == .freeze || event.keyword == .stun {
                    return false
                }
                if effectKind == .shieldAbsorbed {
                    return event.isFullyBlocked
                }
                let descriptor = CombatFeedbackEffectPresentation.descriptor(for: effectKind)
                if descriptor.feedbackClass == .buff || descriptor.feedbackClass == .resource, event.origin != .direct {
                    guard let source = CombatCardSourceKey(event), cardSources.contains(source) else { return false }
                }
                return descriptor.shouldDisplay(amount: event.amount)
            }
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
                let existingEvent = result[index].event
                let representative = existingEvent.kind == .status && source.event.kind != .status
                    ? source.event : existingEvent
                result[index].event = representative.with(
                    amount: existingEvent.amount + source.event.amount,
                    isCritical: existingEvent.isCritical || source.event.isCritical,
                )
                result[index].sourceEventIDs.append(contentsOf: source.sourceEventIDs)
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
        case .abilityDamage, .status:
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

    private static func visualRole(for event: ActionEvent) -> CombatFeedbackVisualRole {
        guard let effectKind = event.effectKind else { return .keyword }
        return CombatFeedbackEffectPresentation.descriptor(for: effectKind).visualRole
    }
}
