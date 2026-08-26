import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

/// Shared enumeration of closed-vocabulary combat feedback chips.
enum CombatFeedbackClosedVocabulary {
    struct Source: Equatable {
        let feedbackClass: CombatFeedbackClass
        let keyword: Keyword
        let visualRole: CombatFeedbackVisualRole
        let label: CombatFeedbackChipLabel
    }

    static func enumerateSources() -> [Source] {
        var sources: [Source] = []
        for outcome in ActionEvent.EffectOutcome.allCases {
            let descriptor = CombatFeedbackEffectPresentation.descriptor(for: outcome)
            guard descriptor.shouldDisplay(amount: 1), isClosedVocabulary(descriptor) else {
                continue
            }
            var seenAppearances: Set<ResolvedAppearance> = []
            for keyword in Keyword.allCases {
                let event = catalogEvent(outcome: outcome, keyword: keyword)
                for item in CombatFeedbackPresenter.makeItems(
                    from: [event],
                    at: Date(timeIntervalSince1970: 0)
                ) {
                    let appearance = ResolvedAppearance(
                        typography: item.feedbackClass.typographyTier,
                        presentation: item.chipPresentation
                    )
                    guard seenAppearances.insert(appearance).inserted else { continue }
                    sources.append(
                        Source(
                            feedbackClass: item.feedbackClass,
                            keyword: item.keyword,
                            visualRole: item.visualRole,
                            label: item.label
                        )
                    )
                }
            }
        }
        return sources
    }

    static func enumerateItems(at date: Date = .now) -> [CombatFeedbackItem] {
        let expiresAt = date.addingTimeInterval(1)
        var items: [CombatFeedbackItem] = []
        var preparedAppearances: Set<PreparedAppearance> = []
        var nextID = 1
        for source in enumerateSources() {
            for role in CombatFeedbackPresentationRole.allCases {
                let item = catalogItem(
                    from: source,
                    id: nextID,
                    presentationRole: role,
                    availableAt: date,
                    expiresAt: expiresAt
                )
                let appearance = PreparedAppearance(
                    typography: item.feedbackClass.typographyTier,
                    presentationRole: role,
                    presentation: item.chipPresentation
                )
                if preparedAppearances.insert(appearance).inserted {
                    items.append(item)
                    nextID += 1
                }
            }
        }
        return items
    }

    static func enumerateWordChips(at date: Date = .now) -> [CombatFeedbackItem] {
        var items: [CombatFeedbackItem] = []
        for outcome in ActionEvent.EffectOutcome.allCases {
            for keyword in Keyword.allCases {
                let event = catalogEvent(outcome: outcome, keyword: keyword)
                for presented in CombatFeedbackPresenter.makeItems(from: [event], at: date) {
                    guard case .word = presented.label else { continue }
                    for role in CombatFeedbackPresentationRole.allCases {
                        items.append(withPresentationRole(presented, role))
                    }
                }
            }
        }
        return items
    }

    private struct PreparedAppearance: Hashable {
        let typography: CombatFeedbackTypographyTier
        let presentationRole: CombatFeedbackPresentationRole
        let presentation: CombatFeedbackChipPresentation
    }

    private struct ResolvedAppearance: Hashable {
        let typography: CombatFeedbackTypographyTier
        let presentation: CombatFeedbackChipPresentation
    }

    private static func isClosedVocabulary(
        _ descriptor: CombatFeedbackEffectPresentation.Descriptor
    ) -> Bool {
        if descriptor.statusLabel != nil {
            return true
        }
        switch descriptor.labelRule {
        case .dodgeWord, .plainKeyword, .appliedKeyword, .triggeredKeyword,
             .cleanseKeyword, .purgeKeyword, .deathsDoorIcon:
            return true
        case .amount, .negatedAmount, nil:
            return false
        }
    }

    private static func catalogEvent(
        outcome: ActionEvent.EffectOutcome,
        keyword: Keyword
    ) -> ActionEvent {
        ActionEvent(
            id: 1,
            actionID: 1,
            kind: .effect,
            effectKind: outcome,
            actorName: "Hero",
            abilityName: "Catalog",
            targetID: "catalog",
            targetName: "Catalog",
            amount: 1,
            keyword: keyword
        )
    }

    private static func catalogItem(
        from source: Source,
        id: Int,
        presentationRole: CombatFeedbackPresentationRole,
        availableAt: Date,
        expiresAt: Date
    ) -> CombatFeedbackItem {
        CombatFeedbackItem(
            id: id,
            sourceEventIDs: [id],
            actionGroupID: id,
            presentationIndex: presentationRole == .headline ? 0 : 1,
            groupResultCount: presentationRole == .headline ? 1 : 4,
            presentationRole: presentationRole,
            targetID: "catalog",
            feedbackClass: source.feedbackClass,
            keyword: source.keyword,
            visualRole: source.visualRole,
            label: source.label,
            availableAt: availableAt,
            expiresAt: expiresAt,
            reactionKind: .none
        )
    }

    private static func withPresentationRole(
        _ item: CombatFeedbackItem,
        _ role: CombatFeedbackPresentationRole
    ) -> CombatFeedbackItem {
        CombatFeedbackItem(
            id: item.id,
            sourceEventIDs: item.sourceEventIDs,
            actionGroupID: item.actionGroupID,
            presentationIndex: role == .headline ? 0 : 1,
            groupResultCount: role == .headline ? 1 : 4,
            presentationRole: role,
            targetID: item.targetID,
            feedbackClass: item.feedbackClass,
            keyword: item.keyword,
            visualRole: item.visualRole,
            label: item.label,
            availableAt: item.availableAt,
            expiresAt: item.expiresAt,
            reactionKind: item.reactionKind
        )
    }
}
