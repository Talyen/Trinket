import Testing
import TrinketDesignSystem

struct TrinketMotionTests {
    @Test func battleMotionTimingTokensStayWithinContracts() {
        #expect(TrinketMotion.Battle.skillSoftHold == 0.5)
        let total = TrinketMotion.Battle.skillCalloutIn
            + TrinketMotion.Battle.skillCalloutHold
            + TrinketMotion.Battle.skillCalloutOut
        #expect(TrinketMotion.Battle.skillCalloutTotal == total)
        #expect(TrinketMotion.Battle.ultimateSkipLockout > 0)
        #expect(TrinketMotion.Battle.ultimateChipStagger > 0)
        #expect(TrinketMotion.Battle.ultimateChipStagger < 0.2)
        #expect(TrinketMotion.Labyrinth.modifierStagger > 0)
        #expect(TrinketMotion.Labyrinth.modifierStagger < 0.2)
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

    @Test func chipMotionRecipesStayWithinSemanticContracts() {
        let critical = TrinketMotion.Battle.chip(for: .critical)
        let dot = TrinketMotion.Battle.chip(for: .dot)
        #expect(critical.lifetime > dot.lifetime)
        #expect(critical.textStyle == .largeTitle)
        #expect(dot.textStyle == .title2)
        #expect(critical.showsSecondaryCaption)
        for feedbackClass in CombatFeedbackClass.allCases {
            let recipe = TrinketMotion.Battle.chip(for: feedbackClass)
            #expect(recipe.lifetime <= 0.85)
            #expect(recipe.lifetime >= 0.6)
            #expect(recipe.initialOpacity == 0)
            #expect(recipe.initialScale < 1)
            #expect(recipe.initialOffsetY > 0)
            #expect((recipe.offsetY.last?.value ?? 0) <= -40)
        }
        #expect(TrinketMotion.Battle.maxChipLifetime > TrinketMotion.Battle.chipDisplayDuration)
        #expect(CombatFeedbackLayout.presentationOffset(index: 0) == 0)
        #expect(CombatFeedbackLayout.presentationOffset(index: 1) > 40)
        #expect(
            CombatFeedbackLayout.presentationOffset(index: 2)
                > CombatFeedbackLayout.presentationOffset(index: 1)
        )
    }

    @Test func cardReactionsCoverAllKinds() {
        for kind in CombatantHitReactionKind.allCases {
            let recipe = TrinketMotion.Battle.cardReaction(for: kind)
            #expect(recipe.kind == kind)
            #expect(recipe.duration > 0)
        }
    }
}
