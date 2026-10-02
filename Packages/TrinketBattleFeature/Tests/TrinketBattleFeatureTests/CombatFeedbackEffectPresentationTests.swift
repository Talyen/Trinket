import BattleEngine
import Testing
import TrinketDesignSystem
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

        let thorns = CombatFeedbackEffectPresentation.chipPresentation(for: .thorns, keyword: .thorns)
        #expect(thorns.trailingStyle == .keyword(.thorns))
    }

    @Test func `hit reaction recipe computed properties and fallbacks`() {
        let defaultDamage = CombatFeedbackCardRecipes.cardReaction(for: .damage)
        #expect(defaultDamage.keyframes.impactDuration > 0)
        #expect(defaultDamage.keyframes.recoveryDuration > 0)
        #expect(defaultDamage.keyframes.rawImpactScaleX > 0)
        #expect(defaultDamage.keyframes.rawImpactScaleY > 0)
        #expect(defaultDamage.keyframes.recoveryScaleX > 0)
        #expect(defaultDamage.keyframes.recoveryScaleY > 0)

        let emptyRecipe = CombatantHitReactionRecipe(
            kind: .none,
            scaleX: [],
            scaleY: [],
            offsetX: [],
            offsetY: [],
            duration: 0.24,
        )
        #expect(emptyRecipe.keyframes.impactDuration == 0.08)
        #expect(emptyRecipe.keyframes.recoveryDuration == 0.16)
        #expect(emptyRecipe.keyframes.rawImpactScaleX == 1.0)
        #expect(emptyRecipe.keyframes.rawImpactScaleY == 1.0)
        #expect(emptyRecipe.keyframes.recoveryScaleX == 1.0)
        #expect(emptyRecipe.keyframes.recoveryScaleY == 1.0)
        #expect(emptyRecipe.keyframes.rawImpactOffsetX == 0.0)
        #expect(emptyRecipe.keyframes.rawImpactOffsetY == 0.0)
        #expect(emptyRecipe.keyframes.recoverOffsetX == 0.0)
        #expect(emptyRecipe.keyframes.recoverOffsetY == 0.0)
    }
}
