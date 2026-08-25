import BattleEngine
import Testing
@testable import TrinketBattleFeature

struct CombatFeedbackEffectPresentationTests {
    /// Every engine effect outcome must have a presentation descriptor so new
    /// outcomes surface here instead of silently rendering as a generic chip.
    @Test func everyEffectOutcomeHasADescriptor() {
        for outcome in ActionEvent.EffectOutcome.allCases {
            _ = CombatFeedbackEffectPresentation.descriptor(for: outcome)
        }
    }

    @Test func descriptorValuesMatchPresenterContract() {
        // Spot-check load-bearing rows so a copy-paste slip inside the table
        // fails here rather than rendering the wrong chip in battle.
        let heal = CombatFeedbackEffectPresentation.descriptor(for: .instantHeal)
        #expect(heal.feedbackClass == .heal)
        #expect(heal.isAdditive)
        #expect(heal.labelRule == .amount)

        let absorbed = CombatFeedbackEffectPresentation.descriptor(for: .shieldAbsorbed)
        #expect(absorbed.feedbackClass == .block)
        #expect(absorbed.isAdditive)
        #expect(absorbed.labelRule == .negatedAmount)

        let dodge = CombatFeedbackEffectPresentation.descriptor(for: .dodgeApplied)
        #expect(dodge.feedbackClass == .dodge)
        #expect(!dodge.isAdditive)
        #expect(dodge.labelRule == .dodgeWord)

        let deathsDoor = CombatFeedbackEffectPresentation.descriptor(for: .deathsDoorTriggered)
        #expect(deathsDoor.feedbackClass == .deathsDoor)
        #expect(deathsDoor.labelRule == .deathsDoorIcon)

        let ward = CombatFeedbackEffectPresentation.descriptor(for: .wardApplied)
        #expect(ward.feedbackClass == .buff)
        #expect(ward.visualRole == .beneficialStatus)
        #expect(ward.statusLabel == .ward)
        #expect(ward.labelRule == nil)

        let cleanse = CombatFeedbackEffectPresentation.descriptor(for: .cleanseApplied)
        let purge = CombatFeedbackEffectPresentation.descriptor(for: .purgeApplied)
        #expect(cleanse.labelRule == .cleanseKeyword)
        #expect(purge.labelRule == .purgeKeyword)

        let recurring = CombatFeedbackEffectPresentation.descriptor(for: .recurringDamageApplied)
        #expect(recurring.feedbackClass == .dot)
        #expect(recurring.labelRule == .appliedKeyword)

        let amplified = CombatFeedbackEffectPresentation.descriptor(for: .dotAmplified)
        #expect(amplified.feedbackClass == .dot)
        #expect(amplified.labelRule == .triggeredKeyword)
    }

    @Test func descriptorDisplayRulesMatchVisibilityPolicy() {
        #expect(
            CombatFeedbackEffectPresentation.descriptor(for: .cardsDrawn).displayRule == .hidden
        )
        #expect(
            CombatFeedbackEffectPresentation.descriptor(for: .controlApplied).displayRule == .hidden
        )
        #expect(
            CombatFeedbackEffectPresentation.descriptor(for: .leechApplied).displayRule == .hidden
        )
        #expect(
            CombatFeedbackEffectPresentation.descriptor(for: .resourceGain).displayRule
                == .positiveAmountOnly
        )
        #expect(CombatFeedbackEffectPresentation.descriptor(for: .instantHeal).displayRule == .visible)

        let resource = CombatFeedbackEffectPresentation.descriptor(for: .resourceGain)
        #expect(resource.shouldDisplay(amount: 3))
        #expect(resource.shouldDisplay(amount: 0))
        #expect(!resource.shouldDisplay(amount: -3))
        #expect(!CombatFeedbackEffectPresentation.descriptor(for: .cardsDrawn).shouldDisplay(amount: 2))
    }
}
