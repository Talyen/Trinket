import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import TrinketBattleFeature

struct CombatFeedbackMotionTests {
    @Test func `typography tiers match feedback classes`() {
        #expect(CombatFeedbackClass.critical.typographyTier == .emphasis)
        #expect(CombatFeedbackClass.deathsDoor.typographyTier == .emphasis)
        #expect(CombatFeedbackClass.directDamage.typographyTier == .normal)
        #expect(CombatFeedbackClass.heal.typographyTier == .normal)
        #expect(CombatFeedbackClass.block.typographyTier == .normal)

        let critStyle = CombatFeedbackChipStyle.forClass(.critical)
        #expect(critStyle.fontWeight == .heavy)
        #expect(critStyle.textStyle == .largeTitle)

        let damageStyle = CombatFeedbackChipStyle.forClass(.directDamage)
        #expect(damageStyle.fontWeight == .bold)
        #expect(damageStyle.textStyle == .title)
    }

    @Test func `hit recoil direction calculates offsets and scales`() {
        let up = CombatantHitRecoilDirection.up
        let down = CombatantHitRecoilDirection.down

        #expect(up.impactOffset(magnitude: 12) == CGSize(width: 0, height: -12))
        #expect(down.impactOffset(magnitude: 12) == CGSize(width: 0, height: 12))

        let upScales = up.impactScales(scaleX: 0.9, scaleY: 1.1)
        #expect(upScales.x == 1.1)
        #expect(upScales.y == 0.9)

        let downScales = down.impactScales(scaleX: 0.9, scaleY: 1.1)
        #expect(downScales.x == 0.9)
        #expect(downScales.y == 1.1)
    }

    @Test func `combat feedback unit noise is bounded and deterministic`() {
        for seed in [0, 1, 42, 100, 9999, -5] {
            let noise1 = CombatFeedbackLayout.unitNoise(seed: seed)
            let noise2 = CombatFeedbackLayout.unitNoise(seed: seed)
            #expect(noise1 == noise2)
            #expect(noise1 >= 0 && noise1 <= 1)
        }
    }

    @Test func `alchemy pop motion progress lifecycle`() {
        #expect(BattleMotion.chipMotionProgress(elapsed: 0) == 0)
        #expect(BattleMotion.chipMotionProgress(elapsed: BattleMotion.alchemyHoldEndTime) == 0)
        let midProgress = BattleMotion.chipMotionProgress(
            elapsed: BattleMotion.alchemyHoldEndTime + 0.225,
        )
        #expect(midProgress > 0 && midProgress < 1)
        let fullProgress = BattleMotion.chipMotionProgress(
            elapsed: BattleMotion.alchemyPopDisplayDuration + 0.1,
        )
        #expect(fullProgress == 1.0)
    }

    @Test func `alchemy pop scale and opacity phases`() {
        #expect(BattleMotion.chipScale(elapsed: 0) == BattleMotion.alchemyPopStartScale)
        #expect(
            abs(BattleMotion.chipScale(elapsed: BattleMotion.alchemyPopPeakTime) - BattleMotion
                .alchemyPopOvershootScale) < 0.001,
        )
        #expect(BattleMotion.chipOpacity(elapsed: 0) == 1.0)
        #expect(BattleMotion.chipOpacity(elapsed: BattleMotion.alchemyPopDisplayDuration) == 0.0)
    }

    @Test func `chip travel distance clamps to safe bounds`() {
        let cardHeight: CGFloat = 200
        let chipHeight: CGFloat = 30
        let distance = BattleMotion.chipTravelDistance(cardHeight: cardHeight, chipHeight: chipHeight)
        #expect(distance > 0)
        #expect(distance <= (cardHeight / 2 - chipHeight / 2 - BattleMotion.chipTopClearance))
    }
}
