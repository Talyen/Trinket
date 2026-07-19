import CoreGraphics
import Testing
import TrinketCore
import TrinketDesignSystem
@testable import Trinket

@MainActor
struct CardActivationTests {
    @Test func cardParticlesArePreparedDeterministically() {
        let first = CardActivationParticle.make(count: 50)
        let second = CardActivationParticle.make(count: 50)

        #expect(first == second)
        #expect(CardActivationParticle.make(count: -1).isEmpty)
    }

    @Test func fireworksParticlesArePreparedDeterministically() {
        let first = CardActivationParticle.makeFireworks(count: 28)
        let second = CardActivationParticle.makeFireworks(count: 28)

        #expect(first == second)
        #expect(first.count == 28)
        #expect(CardActivationParticle.makeFireworks(count: -1).isEmpty)
        // Upward hemisphere: every particle travels with non-positive Y.
        #expect(first.allSatisfy { $0.vector.dy <= 0 })
    }

    @Test func cardActivationRequestNormalizesKeywords() {
        let request = CardActivationRequest(
            artworkName: nil,
            center: .zero,
            size: CGSize(width: 100, height: 140),
            rotation: 0,
            verticalTilt: 0,
            scale: 1,
            keywords: [.burn, .burn, .physical]
        )

        #expect(request.keywords == [.burn, .physical])
        #expect(request.particleCount == TrinketMotion.Battle.cardCastParticleCount)
        #expect(request.particles.count == TrinketMotion.Battle.cardCastParticleCount)
        #expect(abs(request.perspective - 0.35) < 0.0001)
    }
}
