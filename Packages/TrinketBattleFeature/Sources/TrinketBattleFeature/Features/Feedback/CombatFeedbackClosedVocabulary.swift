import BattleEngine
import TrinketContent
import TrinketCore

/// Prewarming needs resolved pixels, not synthetic combat events or scheduled items.
enum CombatFeedbackClosedVocabulary {
    static let appearances: [CombatFeedbackAppearance] = {
        var result: [CombatFeedbackAppearance] = []
        var seen: Set<CombatFeedbackAppearance> = []
        for outcome in ActionEvent.EffectOutcome.allCases {
            let descriptor = CombatFeedbackEffectPresentation.descriptor(for: outcome)
            guard descriptor.shouldDisplay(amount: 1) else { continue }
            for keyword in Keyword.allCases {
                // Freeze and Stun use their dedicated animations instead of floating chips.
                if outcome == .controlTriggered || outcome == .controlActionSkipped,
                   keyword == .freeze || keyword == .stun {
                    continue
                }
                guard let label = descriptor.label(amount: 1, keyword: keyword), case .word = label else { continue }
                let appearance = CombatFeedbackAppearance(
                    feedbackClass: descriptor.feedbackClass,
                    presentation: .resolve(
                        label: label, keyword: keyword, visualRole: descriptor.visualRole,
                        feedbackClass: descriptor.feedbackClass,
                    ),
                )
                if seen.insert(appearance).inserted {
                    result.append(appearance)
                }
            }
        }
        result += CombatReaction.allCases.map { reaction in
            CombatFeedbackAppearance(
                feedbackClass: .buff,
                presentation: .resolve(
                    label: .reaction(reaction),
                    keyword: reaction.damageKeyword,
                    visualRole: .keyword,
                    feedbackClass: .buff,
                ),
            )
        }
        return result
    }()
}
