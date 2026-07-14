import Testing
@testable import Trinket

@MainActor
struct CardActivationTests {
    @Test func cardParticlesArePreparedDeterministically() {
        let first = CardActivationParticle.make(count: 50)
        let second = CardActivationParticle.make(count: 50)

        #expect(first == second)
        #expect(CardActivationParticle.make(count: -1).isEmpty)
    }
}
