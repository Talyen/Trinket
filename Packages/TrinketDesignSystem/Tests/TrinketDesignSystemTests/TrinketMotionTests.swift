import CoreGraphics
import Testing
import TrinketDesignSystem

struct TrinketMotionTests {
    @Test func rewardAndScreenTimingKeepOrderingContracts() {
        #expect(TrinketMotion.Reward.itemRevealDelay > TrinketMotion.Reward.resourceStagger)
        #expect(TrinketMotion.Reward.completionDelay > TrinketMotion.Reward.itemRevealDelay)
        #expect(TrinketMotion.Battle.ultimateFallbackHold > 0)
        #expect(TrinketMotion.Battle.ultimateVideoWatchdog > TrinketMotion.Battle.ultimateFallbackHold)
        #expect(TrinketMotion.Battle.ultimateSplitOpen > 0)
        #expect(TrinketMotion.Battle.ultimateSplitClose > 0)
        #expect(TrinketMotion.Battle.ultimateSplitClose <= TrinketMotion.Battle.ultimateSplitOpen)
        #expect(TrinketMotion.Battle.ultimateCinematicPlaybackSpeed > 0)
        #expect(
            TrinketMotion.Battle.ultimateSplitOpenAtPlayback
                == TrinketMotion.Battle.ultimateSplitOpen
                / TrinketMotion.Battle.ultimateCinematicPlaybackSpeed
        )
        #expect(
            TrinketMotion.Battle.ultimateSplitCloseAtPlayback
                == TrinketMotion.Battle.ultimateSplitClose
                / TrinketMotion.Battle.ultimateCinematicPlaybackSpeed
        )
        #expect(
            TrinketMotion.Battle.ultimateSplitCloseAtPlayback
                <= TrinketMotion.Battle.ultimateSplitOpenAtPlayback
        )
        #expect(TrinketMotion.Battle.feedbackStreamStagger > 0)
        #expect(TrinketMotion.Battle.feedbackStreamStagger < TrinketMotion.Battle.chipDisplayDuration)
        #expect(CombatFeedbackLayout.streamGap > 0)
        #expect(TrinketMotion.Battle.statusBorderPulseDuration > 0)
        #expect(TrinketMotion.Battle.statusBorderPulseDimOpacity > 0)
        #expect(TrinketMotion.Battle.statusBorderPulseDimOpacity < 1)
        #expect(TrinketMotion.Battle.buffAuraShimmerPeriod > 0)
        #expect(TrinketMotion.Battle.combatantSliceDuration > TrinketMotion.Battle.cardActivationDuration)
        #expect(TrinketMotion.Battle.outcomePresentationMinimum > TrinketMotion.Battle.cardActivationDuration)
        #expect(
            TrinketMotion.Battle.outcomePresentationMinimum
                >= TrinketMotion.Battle.combatantSliceDuration
        )
        #expect(TrinketMotion.Battle.combatantStatusEffectPhaseDuration > 0)
        #expect(TrinketMotion.Content.secondEntranceDelay == TrinketMotion.Content.entranceStagger * 2)
        #expect(TrinketMotion.Battle.maxConcurrentCardCasts == 1)
        #expect(
            TrinketMotion.Battle.skillCalloutTotal
                == TrinketMotion.Battle.skillCalloutIn
                + TrinketMotion.Battle.skillCalloutHold
                + TrinketMotion.Battle.skillCalloutOut
        )
        #expect(TrinketMotion.Battle.activeFloatRecipe == .alchemyPop)
        #expect(TrinketMotion.Battle.chipDisplayDuration == TrinketMotion.Battle.alchemyPopDisplayDuration)
    }

    @Test func idealCoreChipMotionUsesEaseOutRiseAndFade() {
        let recipe = CombatFeedbackFloatRecipe.idealCore
        let duration = TrinketMotion.Battle.displayDuration(for: recipe)
        #expect(duration == TrinketMotion.Battle.idealCoreDisplayDuration)
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

        #expect(TrinketMotion.Battle.chipMotionProgress(elapsed: 0, recipe: recipe) == 0)
        #expect(TrinketMotion.Battle.chipMotionProgress(elapsed: duration, recipe: recipe) == 1)
        // Ease-out covers more distance early than late.
        let firstQuarter = TrinketMotion.Battle.chipMotionProgress(elapsed: duration * 0.25, recipe: recipe)
        let secondQuarter = TrinketMotion.Battle.chipMotionProgress(elapsed: duration * 0.5, recipe: recipe)
            - firstQuarter
        let lastQuarter = TrinketMotion.Battle.chipMotionProgress(elapsed: duration, recipe: recipe)
            - TrinketMotion.Battle.chipMotionProgress(elapsed: duration * 0.75, recipe: recipe)
        #expect(firstQuarter > secondQuarter)
        #expect(secondQuarter > lastQuarter)

        #expect(
            TrinketMotion.Battle.chipScale(elapsed: 0, recipe: recipe)
                == TrinketMotion.Battle.chipStartScale
        )
        #expect(
            TrinketMotion.Battle.chipScale(
                elapsed: duration * TrinketMotion.Battle.chipPeakProgress,
                recipe: recipe
            ) == TrinketMotion.Battle.chipPeakScale
        )
        #expect(
            TrinketMotion.Battle.chipScale(elapsed: duration, recipe: recipe)
                == TrinketMotion.Battle.chipEndScale
        )

        let holdEnd = duration * TrinketMotion.Battle.chipOpaqueHoldFraction
        #expect(TrinketMotion.Battle.chipOpacity(elapsed: 0, recipe: recipe) == 1)
        #expect(TrinketMotion.Battle.chipOpacity(elapsed: holdEnd, recipe: recipe) == 1)
        #expect(
            TrinketMotion.Battle.chipOpacity(
                elapsed: holdEnd + TrinketMotion.Battle.chipFadeOutDuration,
                recipe: recipe
            ) == 0
        )

        let travel = TrinketMotion.Battle.chipTravelDistance(cardHeight: 200, chipHeight: 40)
        #expect(travel > 0)
        #expect(100 - travel >= 20 + TrinketMotion.Battle.chipTopClearance)
        #expect(TrinketMotion.Battle.maxChipLifetime > TrinketMotion.Battle.chipDisplayDuration)
    }

    @Test func alchemyPopChipMotionUsesPopHoldCubicRiseAndFade() {
        let recipe = CombatFeedbackFloatRecipe.alchemyPop
        let duration = TrinketMotion.Battle.displayDuration(for: recipe)
        #expect(duration == 0.63)

        let popPeak = TrinketMotion.Battle.alchemyPopDuration * 0.75
        let popEnd = TrinketMotion.Battle.alchemyPopDuration
        let holdEnd = popEnd + TrinketMotion.Battle.alchemyPopHoldDuration
        let fadeStart = max(holdEnd, duration - TrinketMotion.Battle.alchemyPopFadeDuration)

        #expect(
            TrinketMotion.Battle.chipScale(elapsed: 0, recipe: recipe)
                == TrinketMotion.Battle.alchemyPopStartScale
        )
        #expect(
            TrinketMotion.Battle.chipScale(elapsed: popPeak, recipe: recipe)
                == TrinketMotion.Battle.alchemyPopOvershootScale
        )
        #expect(
            TrinketMotion.Battle.chipScale(elapsed: popEnd, recipe: recipe)
                == TrinketMotion.Battle.alchemyPopHoldScale
        )
        #expect(
            TrinketMotion.Battle.chipScale(elapsed: holdEnd, recipe: recipe)
                == TrinketMotion.Battle.alchemyPopHoldScale
        )
        #expect(
            TrinketMotion.Battle.chipScale(elapsed: duration, recipe: recipe)
                == TrinketMotion.Battle.alchemyPopEndScale
        )

        #expect(TrinketMotion.Battle.chipMotionProgress(elapsed: 0, recipe: recipe) == 0)
        #expect(TrinketMotion.Battle.chipMotionProgress(elapsed: holdEnd, recipe: recipe) == 0)
        #expect(TrinketMotion.Battle.chipMotionProgress(elapsed: duration, recipe: recipe) == 1)
        // Cubic ease-in: late rise covers more distance than early rise.
        let earlyRise = TrinketMotion.Battle.chipMotionProgress(
            elapsed: holdEnd + TrinketMotion.Battle.alchemyPopRiseDuration * 0.25,
            recipe: recipe
        )
        let midRise = TrinketMotion.Battle.chipMotionProgress(
            elapsed: holdEnd + TrinketMotion.Battle.alchemyPopRiseDuration * 0.5,
            recipe: recipe
        )
        let lateRise = TrinketMotion.Battle.chipMotionProgress(
            elapsed: holdEnd + TrinketMotion.Battle.alchemyPopRiseDuration * 0.75,
            recipe: recipe
        )
        #expect(midRise - earlyRise < lateRise - midRise)

        #expect(TrinketMotion.Battle.chipOpacity(elapsed: 0, recipe: recipe) == 1)
        #expect(TrinketMotion.Battle.chipOpacity(elapsed: fadeStart, recipe: recipe) == 1)
        #expect(TrinketMotion.Battle.chipOpacity(elapsed: duration, recipe: recipe) == 0)

        // Default helpers dispatch to Alchemy Pop.
        #expect(TrinketMotion.Battle.chipScale(elapsed: 0) == TrinketMotion.Battle.alchemyPopStartScale)
        #expect(TrinketMotion.Battle.chipMotionProgress(elapsed: holdEnd) == 0)
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
