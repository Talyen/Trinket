import CoreGraphics
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

    @Test func rewardRevealTimingStaysBriefAndSequential() {
        #expect(TrinketMotion.Reward.resourceStagger > 0)
        #expect(TrinketMotion.Reward.resourceStagger < 0.2)
        #expect(TrinketMotion.Reward.itemRevealDelay > TrinketMotion.Reward.resourceStagger)
        #expect(TrinketMotion.Reward.completionDelay > TrinketMotion.Reward.itemRevealDelay)
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
        #expect(!critical.showsSecondaryCaption)
        #expect((critical.scale.last?.value ?? 0) > (TrinketMotion.Battle.chip(for: .directDamage).scale.last?.value ?? 0))
        for feedbackClass in CombatFeedbackClass.allCases {
            let recipe = TrinketMotion.Battle.chip(for: feedbackClass)
            #expect(recipe.lifetime <= 1.2)
            #expect(recipe.lifetime >= 0.85)
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

    @Test func combatFeedbackFloatAnglesAreStableAndProduceBothDirections() {
        let range: ClosedRange<CGFloat> = -26 ... 26
        let first = CombatFeedbackLayout.floatAngle(seed: 17, range: range)
        let repeated = CombatFeedbackLayout.floatAngle(seed: 17, range: range)
        let other = CombatFeedbackLayout.floatAngle(seed: 18, range: range)
        let sampledAngles = (0 ..< 32).map {
            CombatFeedbackLayout.floatAngle(seed: $0, range: range)
        }

        #expect(first == repeated)
        #expect(first >= range.lowerBound)
        #expect(first <= range.upperBound)
        #expect(sampledAngles.contains { $0 < 0 })
        #expect(sampledAngles.contains { $0 > 0 })
        #expect(CombatFeedbackLayout.horizontalDrift(angleDegrees: 20, verticalTravel: 60) > 0)
        #expect(CombatFeedbackLayout.horizontalDrift(angleDegrees: -20, verticalTravel: 60) < 0)
        #expect(first != other)
    }

    @Test func cardReactionsCoverAllKinds() {
        for kind in CombatantHitReactionKind.allCases {
            let recipe = TrinketMotion.Battle.cardReaction(for: kind)
            #expect(recipe.kind == kind)
            #expect(recipe.duration > 0)
        }
    }
}
