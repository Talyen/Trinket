import Testing
import TrinketDesignSystem
import TrinketFeatureSupport
@testable import TrinketBattleFeature

@MainActor
struct CombatFeedbackRecipeTests {
    @Test func attackLungeImpactDelayMatchesWindUpPlusSwing() {
        let lunge = CombatFeedbackAttackRecipes.cardAttack(for: .attack)
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
