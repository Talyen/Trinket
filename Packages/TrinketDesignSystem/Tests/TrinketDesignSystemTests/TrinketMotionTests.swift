import Testing
import TrinketDesignSystem

struct TrinketMotionTests {
    @Test func journeyReduceMotionFadeIsBrief() {
        #expect(TrinketMotion.Journey.reduceMotionFade == 0.18)
    }

    @Test func battleSkillSoftHoldIsHalfSecond() {
        #expect(TrinketMotion.Battle.skillSoftHold == 0.5)
    }

    @Test func battleSkillCalloutTotalMatchesParts() {
        let total = TrinketMotion.Battle.skillCalloutIn
            + TrinketMotion.Battle.skillCalloutHold
            + TrinketMotion.Battle.skillCalloutOut
        #expect(TrinketMotion.Battle.skillCalloutTotal == total)
    }

    @Test func battleUltimateSkipLockoutIsPositive() {
        #expect(TrinketMotion.Battle.ultimateSkipLockout > 0)
    }

    @Test func everyCombatFeedbackClassHasPositiveLifetimeRecipe() {
        for feedbackClass in CombatFeedbackClass.allCases {
            let recipe = TrinketMotion.Battle.chip(for: feedbackClass)
            #expect(recipe.lifetime > 0)
            #expect(recipe.scale.count == 3)
            #expect(recipe.opacity.count == 3)
            #expect(recipe.offsetY.count == 3)
            #expect(recipe.feedbackClass == feedbackClass)
        }
    }

    @Test func criticalChipIsHeavierThanDotChip() {
        let critical = TrinketMotion.Battle.chip(for: .critical)
        let dot = TrinketMotion.Battle.chip(for: .dot)
        #expect(critical.lifetime > dot.lifetime)
        #expect(critical.textStyle == .title)
        #expect(dot.textStyle == .footnote)
        #expect(critical.showsSecondaryCaption)
    }

    @Test func chipLifetimesAreBrief() {
        for feedbackClass in CombatFeedbackClass.allCases {
            let recipe = TrinketMotion.Battle.chip(for: feedbackClass)
            #expect(recipe.lifetime <= 0.9)
            #expect(recipe.lifetime >= 0.5)
        }
        #expect(TrinketMotion.Battle.maxChipLifetime > TrinketMotion.Battle.chipDisplayDuration)
    }

    @Test func cardReactionsCoverAllKinds() {
        for kind in CombatantHitReactionKind.allCases {
            let recipe = TrinketMotion.Battle.cardReaction(for: kind)
            #expect(recipe.kind == kind)
            #expect(recipe.duration > 0)
        }
    }

    @Test func ultimateChipStaggerIsPositiveAndShort() {
        #expect(TrinketMotion.Battle.ultimateChipStagger > 0)
        #expect(TrinketMotion.Battle.ultimateChipStagger < 0.2)
    }

    @Test func labyrinthMotionTokensArePositive() {
        #expect(TrinketMotion.Labyrinth.modifierStagger > 0)
        #expect(TrinketMotion.Labyrinth.modifierStagger < 0.2)
    }
}
