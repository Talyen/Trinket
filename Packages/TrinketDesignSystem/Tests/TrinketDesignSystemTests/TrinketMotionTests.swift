import CoreGraphics
import Testing
import TrinketDesignSystem

struct TrinketMotionTests {
    @Test func rewardAndScreenTimingKeepOrderingContracts() {
        #expect(TrinketMotion.Reward.itemRevealDelay > TrinketMotion.Reward.resourceStagger)
        #expect(TrinketMotion.Reward.completionDelay > TrinketMotion.Reward.itemRevealDelay)
        #expect(TrinketMotion.Battle.ultimateSplitClose <= TrinketMotion.Battle.ultimateSplitOpen)
        #expect(
            TrinketMotion.Battle.ultimateSplitCloseAtPlayback
                <= TrinketMotion.Battle.ultimateSplitOpenAtPlayback
        )
        #expect(TrinketMotion.Battle.feedbackStreamStagger < TrinketMotion.Battle.chipDisplayDuration)
        #expect(TrinketMotion.Battle.combatantSliceDuration > TrinketMotion.Battle.cardActivationDuration)
        #expect(
            TrinketMotion.Battle.combatantFreezeEncroachDuration
                < TrinketMotion.Battle.combatantStatusEffectPhaseDuration
        )
        #expect(TrinketMotion.Battle.outcomePresentationMinimum > TrinketMotion.Battle.cardActivationDuration)
        #expect(
            TrinketMotion.Battle.outcomePresentationMinimum
                >= TrinketMotion.Battle.combatantSliceDuration
        )
        #expect(
            TrinketMotion.Battle.skillCalloutTotal
                == TrinketMotion.Battle.skillCalloutIn
                + TrinketMotion.Battle.skillCalloutHold
                + TrinketMotion.Battle.skillCalloutOut
        )
        #expect(TrinketMotion.Mystery.veilHold < TrinketMotion.Mystery.unmaskResponse)
        #expect(TrinketMotion.Mystery.chromeStagger < TrinketMotion.Mystery.recruitButtonDelay)
        #expect(TrinketMotion.Mystery.sealHoldBeforeDismiss > 0)
        #expect(TrinketMotion.Mystery.bloomPeakFraction > 0)
        #expect(TrinketMotion.Mystery.bloomPeakFraction < 1)
        #expect(TrinketMotion.Homestead.connectorFillDuration < TrinketMotion.Homestead.nodeSettleResponse)
        #expect(TrinketMotion.Homestead.nodeSettleDelay == TrinketMotion.Homestead.connectorFillDuration)
        #expect(TrinketMotion.Homestead.connectorFillStagger < TrinketMotion.Homestead.connectorFillDuration)
        #expect(TrinketMotion.Homestead.nodeSettlePeakScale > 1)
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
