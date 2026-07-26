import Testing
import TrinketDesignSystem
@testable import Trinket

@MainActor
struct CombatFeedbackRecipeTests {
    @Test func chipStylesCoverEveryFeedbackClass() {
        for feedbackClass in CombatFeedbackClass.allCases {
            let style = CombatFeedbackChipRecipes.chip(for: feedbackClass)
            #expect(style.feedbackClass == feedbackClass)
        }
    }

    @Test func cardReactionsCoverAllKinds() {
        for kind in CombatantHitReactionKind.allCases {
            let recipe = CombatFeedbackCardRecipes.cardReaction(for: kind)
            #expect(recipe.kind == kind)
            #expect(recipe.duration > 0)
        }

        let damage = CombatFeedbackCardRecipes.cardReaction(for: .damage)
        let critical = CombatFeedbackCardRecipes.cardReaction(for: .critical)
        #expect((damage.scaleX.first?.value ?? 1) < 1)
        #expect((damage.scaleY.first?.value ?? 1) > 1)
        #expect(abs(damage.offsetX.first?.value ?? 0) > 0)
        #expect(abs(critical.offsetX.first?.value ?? 0) > abs(damage.offsetX.first?.value ?? 0))
        #expect((critical.scaleX.first?.value ?? 1) < (damage.scaleX.first?.value ?? 1))

        let celebrate = CombatFeedbackCardRecipes.cardReaction(for: .celebrate)
        #expect((celebrate.scaleX.first?.value ?? 0) > 1)
        #expect((celebrate.scaleY.first?.value ?? 1) < 1)
        #expect((celebrate.offsetY.first?.value ?? 0) < 0)
        #expect(celebrate.rotation.count >= 2)
        #expect((celebrate.rotation.first?.value ?? 0) < 0)
        #expect(celebrate.rotation[1].value > 0)
    }

    @Test func cardAttacksCoverAllKindsAndLungeImpactTiming() {
        for kind in CombatantAttackReactionKind.allCases {
            let recipe = CombatFeedbackAttackRecipes.cardAttack(for: kind)
            #expect(recipe.kind == kind)
            #expect(recipe.duration > 0)
            #expect(recipe.impactDelay >= 0)
            #expect(recipe.impactDelay <= recipe.duration)
        }

        let lunge = CombatFeedbackAttackRecipes.cardAttack(for: .attack)
        #expect(lunge.scaleX.count == lunge.scaleY.count)
        #expect(lunge.offsetY.count == lunge.scaleX.count)
        #expect(lunge.rotation.count == lunge.scaleX.count)
        #expect(lunge.offsetY.count >= 3)
        #expect((lunge.offsetY[0].value) < 0)
        #expect((lunge.offsetY[1].value) > 0)
        #expect(lunge.offsetY[2].value == 0)
        let windUpPlusSwing = (lunge.offsetY[0].duration) + (lunge.offsetY[1].duration)
        #expect(abs(lunge.impactDelay - windUpPlusSwing) < 0.001)
        #expect(
            abs(lunge.duration - (lunge.windUpDuration + lunge.swingDuration + lunge.recoverDuration))
                < 0.001
        )

        let enemyAim = TrinketMotion.Battle.attackAim(isPartyMember: false)
        let partyAim = TrinketMotion.Battle.attackAim(isPartyMember: true)
        #expect(lunge.windUpPose(aim: enemyAim).offsetY < 0)
        #expect(lunge.swingPose(aim: enemyAim).offsetY > 0)
        #expect(lunge.windUpPose(aim: partyAim).offsetY > 0)
        #expect(lunge.swingPose(aim: partyAim).offsetY < 0)
        #expect(lunge.restPose == .rest)
    }
}
