import CoreGraphics
import Testing
import TrinketCore
import TrinketDesignSystem
@testable import Trinket

@MainActor
struct CardActivationTests {
    @Test func cardActivationRequestRetainsTheReleasePresentation() {
        let request = CardActivationRequest(
            artworkName: "ability_fireball",
            center: CGPoint(x: 184, y: 540),
            size: CGSize(width: 168, height: 224),
            rotation: .pi / 12,
            verticalTilt: 3,
            scale: 1.035,
            keywords: [.burn, .physical],
            particleCount: 147
        )
        #expect(request.artworkName == "ability_fireball")
        #expect(request.center == CGPoint(x: 184, y: 540))
        #expect(request.size == CGSize(width: 168, height: 224))
        #expect(request.rotation == .pi / 12)
        #expect(request.verticalTilt == 3)
        #expect(request.scale == 1.035)
        #expect(request.keywords == [.burn, .physical])
        #expect(request.particleCount == 147)
        #expect(request.particles.count == 147)
    }

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
