import CoreGraphics
import Testing
import TrinketDesignSystem

struct TrinketMotionTests {
    @Test func rewardAndScreenTimingKeepOrderingContracts() {
        #expect(TrinketMotion.Reward.itemRevealDelay > TrinketMotion.Reward.resourceStagger)
        #expect(TrinketMotion.Reward.completionDelay > TrinketMotion.Reward.itemRevealDelay)
        #expect(TrinketMotion.Battle.ultimateFallbackHold > 0)
        #expect(TrinketMotion.Battle.ultimateVideoWatchdog > TrinketMotion.Battle.ultimateFallbackHold)
        #expect(TrinketMotion.Battle.feedbackStreamStagger > 0)
        #expect(TrinketMotion.Battle.feedbackStreamStagger < TrinketMotion.Battle.chipDisplayDuration)
        #expect(CombatFeedbackLayout.streamGap > 0)
        #expect(TrinketMotion.Battle.statusBorderPulseDuration > 0)
        #expect(TrinketMotion.Battle.statusBorderPulseDimOpacity > 0)
        #expect(TrinketMotion.Battle.statusBorderPulseDimOpacity < 1)
        #expect(TrinketMotion.Battle.combatantSliceDuration > TrinketMotion.Battle.cardActivationDuration)
        #expect(TrinketMotion.Battle.combatantStatusEffectPhaseDuration > 0)
        #expect(TrinketMotion.Content.secondEntranceDelay == TrinketMotion.Content.entranceStagger * 2)
        #expect(TrinketMotion.Battle.maxConcurrentCardCasts == 1)
        #expect(TrinketMotion.Battle.maxKeywordBurstsPerPane == 1)
        #expect(
            TrinketMotion.Battle.skillCalloutTotal
                == TrinketMotion.Battle.skillCalloutIn
                + TrinketMotion.Battle.skillCalloutHold
                + TrinketMotion.Battle.skillCalloutOut
        )
    }

    @Test func combatFeedbackChipMotionUsesEaseOutRiseAndFade() {
        let duration = TrinketMotion.Battle.chipDisplayDuration
        #expect(duration > 0)
        #expect(TrinketMotion.Battle.chipFadeOutDuration > 0)
        #expect(TrinketMotion.Battle.chipFadeOutDuration < duration)
        #expect(TrinketMotion.Battle.chipOpaqueHoldFraction > 0)
        #expect(TrinketMotion.Battle.chipOpaqueHoldFraction < 1)
        #expect(TrinketMotion.Battle.chipTravelFraction > 0)
        #expect(TrinketMotion.Battle.chipTravelFraction < 1)
        #expect(TrinketMotion.Battle.chipStartScale > 1)
        #expect(TrinketMotion.Battle.chipPeakScale > TrinketMotion.Battle.chipStartScale)
        #expect(TrinketMotion.Battle.chipEndScale < 1)
        #expect(TrinketMotion.Battle.chipPeakProgress > 0)
        #expect(TrinketMotion.Battle.chipPeakProgress < 1)

        #expect(TrinketMotion.Battle.chipMotionProgress(elapsed: 0) == 0)
        #expect(TrinketMotion.Battle.chipMotionProgress(elapsed: duration) == 1)
        // Ease-out covers more distance early than late.
        let firstQuarter = TrinketMotion.Battle.chipMotionProgress(elapsed: duration * 0.25)
        let secondQuarter = TrinketMotion.Battle.chipMotionProgress(elapsed: duration * 0.5) - firstQuarter
        let lastQuarter = TrinketMotion.Battle.chipMotionProgress(elapsed: duration)
            - TrinketMotion.Battle.chipMotionProgress(elapsed: duration * 0.75)
        #expect(firstQuarter > secondQuarter)
        #expect(secondQuarter > lastQuarter)

        #expect(TrinketMotion.Battle.chipScale(elapsed: 0) == TrinketMotion.Battle.chipStartScale)
        #expect(
            TrinketMotion.Battle.chipScale(elapsed: duration * TrinketMotion.Battle.chipPeakProgress)
                == TrinketMotion.Battle.chipPeakScale
        )
        #expect(TrinketMotion.Battle.chipScale(elapsed: duration) == TrinketMotion.Battle.chipEndScale)

        let holdEnd = duration * TrinketMotion.Battle.chipOpaqueHoldFraction
        #expect(TrinketMotion.Battle.chipOpacity(elapsed: 0) == 1)
        #expect(TrinketMotion.Battle.chipOpacity(elapsed: holdEnd) == 1)
        #expect(TrinketMotion.Battle.chipOpacity(elapsed: holdEnd + TrinketMotion.Battle.chipFadeOutDuration) == 0)

        let travel = TrinketMotion.Battle.chipTravelDistance(cardHeight: 200, chipHeight: 40)
        #expect(travel > 0)
        #expect(100 - travel >= 20 + TrinketMotion.Battle.chipTopClearance)
        #expect(TrinketMotion.Battle.maxChipLifetime > TrinketMotion.Battle.chipDisplayDuration)
    }

    @Test func hitRecoilDirectionFlipsOffsetAndScaleAxes() {
        let magnitude: CGFloat = 4
        let upOffset = CombatantHitRecoilDirection.up.impactOffset(magnitude: magnitude)
        let downOffset = CombatantHitRecoilDirection.down.impactOffset(magnitude: magnitude)
        #expect(upOffset.width == 0)
        #expect(upOffset.height == -magnitude)
        #expect(downOffset.width == 0)
        #expect(downOffset.height == magnitude)

        let upScales = CombatantHitRecoilDirection.up.impactScales(scaleX: 0.96, scaleY: 1.025)
        let downScales = CombatantHitRecoilDirection.down.impactScales(scaleX: 0.96, scaleY: 1.025)
        #expect(upScales.x == 1.025)
        #expect(upScales.y == 0.96)
        #expect(downScales.x == 0.96)
        #expect(downScales.y == 1.025)

        #expect(TrinketMotion.Battle.partyRecoilDirection(isPartyMember: true) == .down)
        #expect(TrinketMotion.Battle.partyRecoilDirection(isPartyMember: false) == .up)
        #expect(TrinketMotion.Battle.attackAim(isPartyMember: false) == .towardParty)
        #expect(TrinketMotion.Battle.attackAim(isPartyMember: true) == .towardEnemy)
    }
}
