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
}
