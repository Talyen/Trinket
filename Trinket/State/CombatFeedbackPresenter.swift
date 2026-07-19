import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem

/// Pure presenter: engine events → classified feedback items.
enum CombatFeedbackPresenter {
    static func makeItems(
        from events: [ActionEvent],
        at date: Date
    ) -> [CombatFeedbackItem] {
        let filteredSources = filterDisplayable(events).enumerated().map { order, event in
            PreparedSource(event: event, sourceEventIDs: [event.id], originalOrder: order)
        }
        let sources = consolidate(collapseAvatarOfJustice(in: filteredSources))
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
            return CombatFeedbackPresentationFactory.makeItems(
                from: sorted.map {
                    CombatFeedbackPresentationFactory.Source(
                        id: $0.id,
                        sourceEventIDs: $0.sourceEventIDs,
                        targetID: $0.targetID,
                        feedbackClass: $0.feedbackClass,
                        keyword: $0.keyword,
                        visualRole: $0.visualRole,
                        label: $0.label,
                        secondaryText: $0.secondaryText,
                        reactionKind: $0.reactionKind
                    )
                },
                actionGroupID: actionGroupID,
                availableAt: availableAt,
                expiresAt: expiresAt
            )
        }
    }

    static func reaction(for items: [CombatFeedbackItem]) -> CombatantHitReaction? {
        guard let item = items.first(where: {
            $0.presentationIndex == 0 && $0.reactionKind != .none
        }) else { return nil }
        return CombatantHitReaction(
            id: item.id,
            kind: item.reactionKind
        )
    }

    /// Keyword particle bursts alongside floating chips are disabled; chips alone
    /// carry feedback. The performance harness may still inject bursts directly.
    static func bursts(for _: [CombatFeedbackItem]) -> [KeywordBurstRequest] {
        []
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

    private struct NamedAbilityGroupKey: Hashable {
        let actionID: Int
        let targetID: String
        let abilityID: String
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

    private static func collapseAvatarOfJustice(in sources: [PreparedSource]) -> [PreparedSource] {
        var collapsed: [PreparedSource] = []
        var emittedGroups = Set<NamedAbilityGroupKey>()

        for source in sources {
            let event = source.event
            guard event.abilityID == "avatar-of-justice", isAvatarPresentationEffect(event.effectKind) else {
                collapsed.append(source)
                continue
            }
            let key = NamedAbilityGroupKey(
                actionID: event.actionID,
                targetID: event.targetID,
                abilityID: event.abilityID
            )
            let matching = sources.filter {
                $0.event.actionID == key.actionID
                    && $0.event.targetID == key.targetID
                    && $0.event.abilityID == key.abilityID
                    && isAvatarPresentationEffect($0.event.effectKind)
            }
            guard let representative = matching.first(where: {
                $0.event.effectKind == .damageKeywordOverrideApplied
            }) else {
                collapsed.append(source)
                continue
            }
            guard emittedGroups.insert(key).inserted else { continue }
            collapsed.append(PreparedSource(
                event: representative.event,
                sourceEventIDs: matching.flatMap(\.sourceEventIDs),
                originalOrder: matching.map(\.originalOrder).min() ?? representative.originalOrder
            ))
        }
        return collapsed.sorted { $0.originalOrder < $1.originalOrder }
    }

    private static func isAvatarPresentationEffect(_ effectKind: ActionEvent.EffectKind?) -> Bool {
        guard let effectKind else { return false }
        return switch effectKind {
        case .shieldApplied, .mitigationApplied, .damageKeywordOverrideApplied:
            true
        default:
            false
        }
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
        let statusPresentation = statusPresentation(for: event)
        let label = statusPresentation.map { CombatFeedbackChipLabel.word(.status($0.label)) }
            ?? CombatFeedbackChipLabel.fromDisplayText(Self.floatingText(from: display))
        guard let label, !label.isZeroNumeric else { return nil }
        return PreparedEvent(
            id: event.id,
            sourceEventIDs: source.sourceEventIDs,
            originalOrder: source.originalOrder,
            actionID: event.actionID,
            targetID: event.targetID,
            feedbackClass: feedbackClass,
            keyword: display.keyword,
            visualRole: statusPresentation?.role ?? .keyword,
            label: label,
            secondaryText: display.secondaryText,
            reactionKind: CombatFeedbackClassification.reactionKind(for: feedbackClass)
        )
    }

    private struct StatusPresentation {
        let label: CombatFeedbackStatusLabel
        let role: CombatFeedbackVisualRole
    }

    private static func statusPresentation(for event: ActionEvent) -> StatusPresentation? {
        guard let effectKind = event.effectKind else { return nil }
        return switch effectKind {
        case .thornsApplied:
            StatusPresentation(label: .thorns, role: .beneficialStatus)
        case .hasteApplied:
            StatusPresentation(label: .hasted, role: .beneficialStatus)
        case .criticalChanceApplied:
            StatusPresentation(label: .criticalUp, role: .beneficialStatus)
        case .manaShieldApplied:
            StatusPresentation(label: .manaShield, role: .beneficialStatus)
        case .damageKeywordOverrideApplied:
            StatusPresentation(
                label: event.abilityID == "avatar-of-justice" ? .avatarOfJustice : .consecrated,
                role: .beneficialStatus
            )
        case .nextHolyStrikeApplied:
            StatusPresentation(label: .nextHolyStrike, role: .beneficialStatus)
        case .markedApplied:
            StatusPresentation(label: .marked, role: .negativeStatus)
        case .mitigationHalved:
            StatusPresentation(label: .armorDown, role: .negativeStatus)
        default:
            nil
        }
    }

    /// Numeric effects use the icon for their keyword identity, so the float only
    /// needs the amount magnitude (and any attached numeric unit such as `%`).
    /// Text-only effects retain their descriptive label, such as "Dodge".
    private static func floatingText(from display: ActionEventDisplay) -> String {
        guard let firstToken = display.text.split(separator: " ").first,
              firstToken.contains(where: \.isNumber) else {
            return display.text
        }
        return String(firstToken)
    }
}
