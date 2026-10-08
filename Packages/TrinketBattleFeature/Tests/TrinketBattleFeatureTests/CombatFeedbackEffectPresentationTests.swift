import BattleEngine
import Testing
@testable import TrinketBattleFeature

struct CombatFeedbackEffectPresentationTests {
    @Test func `descriptor display rules match visibility policy`() {
        #expect(
            CombatFeedbackEffectPresentation.descriptor(for: .cardsDrawn).displayRule == .hidden,
        )
        #expect(
            CombatFeedbackEffectPresentation.descriptor(for: .controlApplied).displayRule == .hidden,
        )
        #expect(
            CombatFeedbackEffectPresentation.descriptor(for: .leechApplied).displayRule == .visible,
        )
        #expect(
            CombatFeedbackEffectPresentation.descriptor(for: .resourceGain).displayRule
                == .positiveAmountOnly,
        )
        #expect(CombatFeedbackEffectPresentation.descriptor(for: .instantHeal).displayRule == .visible)

        let resource = CombatFeedbackEffectPresentation.descriptor(for: .resourceGain)
        #expect(resource.shouldDisplay(amount: 3))
        #expect(resource.shouldDisplay(amount: 0))
        #expect(!resource.shouldDisplay(amount: -3))
        #expect(!CombatFeedbackEffectPresentation.descriptor(for: .cardsDrawn).shouldDisplay(amount: 2))
    }
}
