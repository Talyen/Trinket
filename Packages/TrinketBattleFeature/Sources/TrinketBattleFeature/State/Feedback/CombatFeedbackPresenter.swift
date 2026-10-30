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

    private static func priority(label: CombatFeedbackChipLabel, feedbackClass: CombatFeedbackClass) -> Int {
        if case .reaction = label {
            return 5
        }
        if case .reactionPayoff = label {
            return 5
        }
        return displayPriority(for: feedbackClass)
    }

    private static func classify(_ event: ActionEvent) -> CombatFeedbackClass {
        switch event.kind {
        case .abilityDamage, .status:
            .directDamage
        case .reaction, .ability, .milestone:
            .buff
        case let .effect(effectKind):
            CombatFeedbackEffectPresentation.descriptor(for: effectKind).feedbackClass
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
        let filtered = filterDisplayable(events)
        let primaryEvents = primaryCardEvents(in: filtered)
        let filteredSources = filtered.enumerated().map { order, event in
            PreparedSource(
                event: event, sourceEventIDs: [event.id], originalOrder: order,
                isPrimary: primaryEvents.contains(event.id),
            )
        }
        var groupOrder: [PresentationGroupKey] = []
        var grouped: [
            PresentationGroupKey: [(source: PreparedSource, label: CombatFeedbackChipLabel, feedbackClass: CombatFeedbackClass)]
        ] =
            [:]
        for (source, label) in labels(for: consolidate(filteredSources)) {
            let key = PresentationGroupKey(actionID: actionGroupID ?? source.event.feedbackGroupID, targetID: source.event.targetID)
            if grouped[key] == nil {
                groupOrder.append(key)
            }
            grouped[key, default: []].append((source, label, classify(source.event)))
        }

        return groupOrder.flatMap { key -> [CombatFeedbackItem] in
            let sorted = (grouped[key] ?? []).sorted { lhs, rhs in
                let lhsPriority = lhs.source.isPrimary ? 0 : priority(label: lhs.label, feedbackClass: lhs.feedbackClass)
                let rhsPriority = rhs.source.isPrimary ? 0 : priority(label: rhs.label, feedbackClass: rhs.feedbackClass)
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
                    isPrimaryCardResult: item.source.isPrimary,
                    isCardHealthCost: isCardHealthCost(event),
                )
            }
        }
    }

    private struct PreparedSource: Equatable {
        var event: ActionEvent
        var sourceEventIDs: [Int]
        let originalOrder: Int
        let isPrimary: Bool
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
        let isPrimary: Bool
        let isCardHealthCost: Bool
        let reactionPayoff: CombatReaction?
    }

    private struct PresentationGroupKey: Hashable {
        let actionID: Int
        let targetID: String
    }

    private struct PrimaryCandidate {
        let event: ActionEvent
        let operation: Int
        let isHitOrHeal: Bool
    }

    private static func labels(for sources: [PreparedSource]) -> [(PreparedSource, CombatFeedbackChipLabel)] {
        var consumed: Set<Int> = []
        return sources.compactMap { original in
            var source = original
            guard !consumed.contains(source.event.id) else { return nil }
            guard var label = CombatFeedbackChipLabel.from(event: source.event), !label.isZeroNumeric else { return nil }
            if let payoff = source.event.reactionPayoff,
               sources.contains(where: {
                   $0.event.kind == .reaction(payoff) && $0.event.targetID == source.event.targetID
                       && $0.event.feedbackGroupID == source.event.feedbackGroupID
               }) {
                return nil
            }
            if case let .reaction(reaction) = source.event.kind {
                let payoffs = sources.filter {
                    $0.event.reactionPayoff == reaction && $0.event.targetID == source.event.targetID
                        && $0.event.feedbackGroupID == source.event.feedbackGroupID && $0.event.amount > 0
                }
                if !payoffs.isEmpty {
                    let total = payoffs.reduce(0) { SaturatedArithmetic.saturatingAdd($0, $1.event.amount) }
                    label = .reactionPayoff(reaction, total)
                    source.sourceEventIDs.append(contentsOf: payoffs.lazy.flatMap(\.sourceEventIDs))
                    for duplicate in sources where duplicate.event.id != source.event.id
                        && duplicate.event.kind == .reaction(reaction) && duplicate.event.targetID == source.event.targetID
                        && duplicate.event.feedbackGroupID == source.event.feedbackGroupID {
                        consumed.insert(duplicate.event.id)
                        source.sourceEventIDs += duplicate.sourceEventIDs
                    }
                }
            }
            return (source, label)
        }
    }

    private static func filterDisplayable(_ events: [ActionEvent]) -> [ActionEvent] {
        var cardSources: Set<CombatCardSourceKey>?
        return events.filter { event in
            switch event.kind {
            case .ability, .milestone:
                return false
            case .abilityDamage:
                return event.amount != 0
            case .status, .reaction:
                return true
            case let .effect(effectKind):
                if effectKind == .controlActionSkipped || effectKind == .controlTriggered,
                   event.keyword == .freeze || event.keyword == .stun {
                    return false
                }
                if effectKind == .shieldAbsorbed {
                    return event.isFullyBlocked
                }
                let descriptor = CombatFeedbackEffectPresentation.descriptor(for: effectKind)
                if descriptor.feedbackClass == .buff || descriptor.feedbackClass == .resource, event.origin != .direct {
                    if event.authoredCardOperation != nil {
                        return descriptor.shouldDisplay(amount: event.amount)
                    }
                    guard let source = CombatCardSourceKey(event) else { return false }
                    if cardSources == nil {
                        cardSources = CombatCardSourceKey.cardSources(in: events)
                    }
                    guard cardSources?.contains(source) == true else { return false }
                }
                return descriptor.shouldDisplay(amount: event.amount)
            }
        }
    }

    private static func consolidate(_ sources: [PreparedSource]) -> [PreparedSource] {
        var result: [PreparedSource] = []
        var keyIndices: [AggregationKey: Int] = [:]
        for source in sources {
            guard let key = aggregationKey(for: source) else {
                result.append(source)
                continue
            }
            if let index = keyIndices[key] {
                let existingEvent = result[index].event
                let representative = existingEvent.kind == .status && source.event.kind != .status
                    ? source.event : existingEvent
                result[index].event = representative.with(
                    amount: SaturatedArithmetic.saturatingAdd(existingEvent.amount, source.event.amount),
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

    private static func aggregationKey(for source: PreparedSource) -> AggregationKey? {
        let event = source.event
        let family: AggregationKey.Family
        switch event.kind {
        case .abilityDamage, .status:
            family = .abilityDamage
        case let .effect(effectKind):
            guard CombatFeedbackEffectPresentation.descriptor(for: effectKind).isAdditive
            else { return nil }
            switch classify(event) {
            case .directDamage: family = .abilityDamage
            case .heal: family = .effect(.instantHeal)
            default: family = .effect(effectKind)
            }
        case .reaction, .ability, .milestone:
            return nil
        }
        return AggregationKey(
            actionID: event.feedbackGroupID,
            targetID: event.targetID,
            keyword: classify(event) == .heal ? .health : event.keyword,
            family: family,
            isNegative: event.amount < 0,
            isPrimary: source.isPrimary,
            isCardHealthCost: isCardHealthCost(event),
            reactionPayoff: event.reactionPayoff,
        )
    }

    private static func primaryCardEvents(in events: [ActionEvent]) -> Set<Int> {
        var candidates: [Int: [PrimaryCandidate]] = [:]
        for event in events {
            guard let operation = event.authoredCardOperation,
                  let label = CombatFeedbackChipLabel.from(event: event), !label.isZeroNumeric,
                  event.effectKind != .blockSpent, event.reactionPayoff == nil else { continue }
            if isCardHealthCost(event) {
                continue
            }
            let isHitOrHeal = event.kind == .abilityDamage || event.effectKind == .instantHeal || event.effectKind == .overheal
            candidates[event.feedbackGroupID, default: []].append(PrimaryCandidate(
                event: event,
                operation: operation,
                isHitOrHeal: isHitOrHeal,
            ))
        }
        var result: Set<Int> = []
        for entries in candidates.values {
            var hasHitOrHeal = false
            for entry in entries where entry.isHitOrHeal {
                hasHitOrHeal = true
                result.insert(entry.event.id)
            }
            if !hasHitOrHeal, let first = entries.lazy.map(\.operation).min() {
                result.formUnion(entries.lazy.filter { $0.operation == first }.map(\.event.id))
            }
        }
        return result
    }

    private static func isCardHealthCost(_ event: ActionEvent) -> Bool {
        event.authoredCardOperation != nil && event.kind == .abilityDamage && event.actorID == event.targetID
    }

    private static func visualRole(for event: ActionEvent) -> CombatFeedbackVisualRole {
        guard let effectKind = event.effectKind else { return .keyword }
        return CombatFeedbackEffectPresentation.descriptor(for: effectKind).visualRole
    }
}
