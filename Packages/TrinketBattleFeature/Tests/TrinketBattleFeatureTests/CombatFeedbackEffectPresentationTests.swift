import BattleEngine
import Testing
import TrinketDesignSystem
@testable import TrinketBattleFeature

struct CombatFeedbackEffectPresentationTests {
    @Test func `every effect outcome has A descriptor`() {
        for outcome in ActionEvent.EffectOutcome.allCases {
            _ = CombatFeedbackEffectPresentation.descriptor(for: outcome)
        }
    }

    @Test func `descriptor values match presenter contract`() {
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

    @Test func `descriptor display rules match visibility policy`() {
        #expect(
            CombatFeedbackEffectPresentation.descriptor(for: .cardsDrawn).displayRule == .hidden,
        )
        #expect(
            CombatFeedbackEffectPresentation.descriptor(for: .controlApplied).displayRule == .hidden,
        )
        #expect(
            CombatFeedbackEffectPresentation.descriptor(for: .leechApplied).displayRule == .hidden,
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

    @Test func `every status label resolves chip presentation`() {
        for status in CombatFeedbackStatusLabel.allCases {
            let presentation = CombatFeedbackEffectPresentation.chipPresentation(
                for: status,
                keyword: .physical,
            )
            #expect(presentation.trailingStyle != .beneficialStatus || presentation.leadingStyle != nil)
        }

        let ward = CombatFeedbackEffectPresentation.chipPresentation(for: .ward, keyword: .holy)
        #expect(ward.trailingStyle == .keyword(.holy))

        let marked = CombatFeedbackEffectPresentation.chipPresentation(for: .marked, keyword: .physical)
        #expect(marked.leadingStyle == nil)
        #expect(marked.trailingStyle == .negativeStatus)
        #expect(marked.text == nil)
    }

    @Test func `hit reaction recipe computed properties and fallbacks`() {
        let defaultDamage = CombatFeedbackCardRecipes.cardReaction(for: .damage)
        #expect(defaultDamage.impactDuration > 0)
        #expect(defaultDamage.recoveryDuration > 0)
        #expect(defaultDamage.rawImpactScaleX > 0)
        #expect(defaultDamage.rawImpactScaleY > 0)
        #expect(defaultDamage.recoveryScaleX > 0)
        #expect(defaultDamage.recoveryScaleY > 0)

        let emptyRecipe = CombatantHitReactionRecipe(
            kind: .none,
            scaleX: [],
            scaleY: [],
            offsetX: [],
            offsetY: [],
            duration: 0.24,
        )
        #expect(emptyRecipe.impactDuration == 0.08)
        #expect(emptyRecipe.recoveryDuration == 0.16)
        #expect(emptyRecipe.rawImpactScaleX == 1.0)
        #expect(emptyRecipe.rawImpactScaleY == 1.0)
        #expect(emptyRecipe.recoveryScaleX == 1.0)
        #expect(emptyRecipe.recoveryScaleY == 1.0)
        #expect(emptyRecipe.rawImpactOffsetX == 0.0)
        #expect(emptyRecipe.rawImpactOffsetY == 0.0)
        #expect(emptyRecipe.recoverOffsetX == 0.0)
        #expect(emptyRecipe.recoverOffsetY == 0.0)
    }
}
