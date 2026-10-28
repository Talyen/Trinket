import CoreGraphics
import Foundation
import Testing
@testable import TrinketBattleFeature

struct CombatantSliceParticleTests {
    @Test func `cut particles animate within the card and fade over their lifetime`() {
        let particles = CombatantSliceStyle.cut
        #expect(!particles.isEmpty)
        let cardSize = CGSize(width: 192, height: 256)
        let margin: CGFloat = 120
        var liveCount = 0
        for particle in particles {
            // Before birth and after death nothing draws.
            #expect(particle.sample(progress: 0, cardSize: cardSize) == nil)
            #expect(particle.sample(progress: 1, cardSize: cardSize) == nil)
            let mid = particle.sample(progress: particle.delay + particle.lifetime * 0.4, cardSize: cardSize)
            let late = particle.sample(progress: particle.delay + particle.lifetime * 0.8, cardSize: cardSize)
            guard let mid, let late else { continue }
            liveCount += 1
            // Visible samples stay near the card, shrink, and fade.
            #expect(mid.center.x > -margin && mid.center.x < cardSize.width + margin)
            #expect(mid.center.y > -margin && mid.center.y < cardSize.height + margin)
            #expect(mid.diameter > 0 && late.diameter > 0 && late.diameter <= mid.diameter)
            #expect(mid.opacity > late.opacity && late.opacity >= 0 && mid.opacity <= 1)
        }
        #expect(liveCount == particles.count)
    }
}
