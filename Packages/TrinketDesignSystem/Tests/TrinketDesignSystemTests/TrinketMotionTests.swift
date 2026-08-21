import Testing
@testable import TrinketDesignSystem

struct TrinketMotionTests {
    @Test func shinePhaseAdvancesLinearlyAndWraps() {
        let period = TrinketMotion.Shine.loopPeriod

        #expect(TrinketMotion.Shine.phase(at: 0) == 0)
        #expect(TrinketMotion.Shine.phase(at: period / 2) == 0.5)
        #expect(TrinketMotion.Shine.phase(at: period) == 0)
        #expect(abs(TrinketMotion.Shine.phase(at: period * 1.25) - 0.25) < 0.001)
    }
}
