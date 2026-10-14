import SwiftUI

struct SliceBorderParticlePlan {
    let motion: DissolveParticleParameters
    private let start: CGPoint
    private let direction: CGVector

    init(particle: SliceBorderParticle, cardSize: CGSize, canvasSize: CGSize, configuration: CardDissolveConfiguration) {
        motion = DissolveParticleParameters(configuration: configuration, noise: particle.motionNoise)
        let origin = CGPoint(x: (canvasSize.width - cardSize.width) * 0.5, y: (canvasSize.height - cardSize.height) * 0.5)
        start = CGPoint(x: origin.x + particle.origin.x * cardSize.width, y: origin.y + particle.origin.y * cardSize.height)
        direction = particle.direction
    }

    func position(motion: DissolveParticleSample) -> CGPoint {
        CGPoint(
            x: start.x + direction.dx * motion.distance * motion.easedAge,
            y: start.y + direction.dy * motion.distance * motion.easedAge,
        )
    }
}

final class SliceBorderParticlePlanCache {
    private struct Key: Equatable {
        let particles: [SliceBorderParticle]
        let cardSize: CGSize
        let canvasSize: CGSize
        let configuration: CardDissolveConfiguration
    }

    private var key: Key?
    private var prepared: [SliceBorderParticlePlan] = []

    func plan(
        particles: [SliceBorderParticle], cardSize: CGSize, canvasSize: CGSize, configuration: CardDissolveConfiguration,
    ) -> [SliceBorderParticlePlan] {
        let key = Key(particles: particles, cardSize: cardSize, canvasSize: canvasSize, configuration: configuration)
        guard self.key != key else { return prepared }
        prepared = particles.map {
            SliceBorderParticlePlan(particle: $0, cardSize: cardSize, canvasSize: canvasSize, configuration: configuration)
        }
        self.key = key
        return prepared
    }
}
