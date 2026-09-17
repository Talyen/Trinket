import Testing
@testable import TrinketDesignSystem

struct TrinketMotionTests {
    @Test func `shine phase advances linearly and wraps`() {
        let period = TrinketMotion.Shine.loopPeriod

        #expect(TrinketMotion.Shine.phase(at: 0) == 0)
        #expect(TrinketMotion.Shine.phase(at: period / 2) == 0.5)
        #expect(TrinketMotion.Shine.phase(at: period) == 0)
        #expect(abs(TrinketMotion.Shine.phase(at: period * 1.25) - 0.25) < 0.001)
    }

    @Test func `derived motion intervals stay consistent`() {
        #expect(TrinketMotion.Content.secondEntranceDelay == TrinketMotion.Content.entranceStagger * 2)
        #expect(abs(TrinketMotion.Shine.textLoopPeriod - TrinketMotion.Shine.loopPeriod * 3) < 0.001)
    }

    @Test func `surface press scale differs from card press scale`() {
        #expect(TrinketMotion.Interaction.surfacePressedScale != TrinketMotion.Interaction.artworkCardPressedScale)
    }
}
