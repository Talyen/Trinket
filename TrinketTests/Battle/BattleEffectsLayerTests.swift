import Testing
import TrinketCore
import TrinketDesignSystem
@testable import Trinket

@MainActor
struct CardActivationTests {
    @Test func cardActivationUsesTheFullParticleDuration() {
        #expect(TrinketMotion.Battle.cardActivationDuration == 1.0)
    }

    @Test func cardParticlesArePreparedDeterministically() {
        let first = CardActivationParticle.make(count: 50)
        let second = CardActivationParticle.make(count: 50)

        #expect(first == second)
        #expect(first.count == 50)
        #expect(CardActivationParticle.make(count: -1).isEmpty)
    }
}
