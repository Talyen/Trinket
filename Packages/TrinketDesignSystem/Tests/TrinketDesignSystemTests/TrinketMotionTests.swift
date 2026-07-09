import Testing
import TrinketDesignSystem

@Suite
struct TrinketMotionTests {
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
        #expect(critical.fontSize > dot.fontSize)
        #expect(critical.chrome == .emphasis)
        #expect(dot.chrome == .compact)
        #expect(critical.showsSecondaryCaption)
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
}
