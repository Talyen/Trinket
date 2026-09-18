import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

enum CombatFeedbackClosedVocabulary {
    struct Source: Equatable {
        let feedbackClass: CombatFeedbackClass
        let keyword: Keyword
        let visualRole: CombatFeedbackVisualRole
        let label: CombatFeedbackChipLabel
    }

    private static let staticSources: [Source] = generateSources()

    static func enumerateSources() -> [Source] {
        staticSources
    }

    private static func generateSources() -> [Source] {
        var sources: [Source] = []
        var seenAppearances: Set<ResolvedAppearance> = []
        for outcome in ActionEvent.EffectOutcome.allCases {
            let descriptor = CombatFeedbackEffectPresentation.descriptor(for: outcome)
            guard descriptor.shouldDisplay(amount: 1), isClosedVocabulary(descriptor) else {
                continue
            }
            for keyword in Keyword.allCases {
                let event = catalogEvent(outcome: outcome, keyword: keyword)
                for item in CombatFeedbackPresenter.makeItems(
                    from: [event],
                    at: Date(timeIntervalSince1970: 0),
                ) {
                    let appearance = ResolvedAppearance(
                        typography: item.feedbackClass.typographyTier,
                        presentation: item.chipPresentation,
                    )
                    guard seenAppearances.insert(appearance).inserted else { continue }
                    sources.append(
                        Source(
                            feedbackClass: item.feedbackClass,
                            keyword: item.keyword,
                            visualRole: item.visualRole,
                            label: item.label,
                        ),
                    )
                }
            }
        }
        return sources
    }

    static func enumerateItems(at date: Date = .now) -> [CombatFeedbackItem] {
        let expiresAt = date.addingTimeInterval(1)
        return staticSources.enumerated().map { index, source in
            catalogItem(
                from: source,
                id: index + 1,
                availableAt: date,
                expiresAt: expiresAt,
            )
        }
    }

    static func enumerateWordChips(at date: Date = .now) -> [CombatFeedbackItem] {
        enumerateItems(at: date).filter {
            if case .word = $0.label {
                true
            } else {
                false
            }
        }
    }

    static func orderedChips(at date: Date = .now) -> [CombatFeedbackItem] {
        CombatFeedbackOrdering.orderedChips(from: enumerateItems(at: date))
    }

    static func wordAtlasFragments(for typography: CombatFeedbackTypographyTier) -> [String] {
        var seen: Set<String> = []
        var fragments: [String] = []
        for item in enumerateItems() where item.feedbackClass.typographyTier == typography {
            guard let text = item.chipPresentation.text, !text.isEmpty else { continue }
            if seen.insert(text).inserted {
                fragments.append(text)
            }
        }
        return fragments
    }

    private struct ResolvedAppearance: Hashable {
        let typography: CombatFeedbackTypographyTier
        let presentation: CombatFeedbackChipPresentation
    }

    private static func isClosedVocabulary(
        _ descriptor: CombatFeedbackEffectPresentation.Descriptor,
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
        keyword: Keyword,
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
            keyword: keyword,
        )
    }

    private static func catalogItem(
        from source: Source,
        id: Int,
        availableAt: Date,
        expiresAt: Date,
    ) -> CombatFeedbackItem {
        CombatFeedbackItem(
            id: id,
            sourceEventIDs: [id],
            actionGroupID: id,
            presentationIndex: 0,
            targetID: "catalog",
            feedbackClass: source.feedbackClass,
            keyword: source.keyword,
            visualRole: source.visualRole,
            label: source.label,
            availableAt: availableAt,
            expiresAt: expiresAt,
            reactionKind: .none,
        )
    }
}
