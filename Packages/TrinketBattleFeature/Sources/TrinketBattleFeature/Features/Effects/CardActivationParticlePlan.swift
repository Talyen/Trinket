import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct DissolveParticleParameters {
    let distance: CGFloat
    private let delay: CGFloat
    private let lifetime: CGFloat
    private let baseDiameter: CGFloat
    private let sizeShrink: CGFloat
    private let fadeStart: CGFloat
    private let fadeExponent: CGFloat
    private let ageEasePower: CGFloat

    init(configuration: CardDissolveConfiguration, noise: DissolveParticleNoise) {
        distance = configuration.particleDistance + noise.distance * configuration.particleDistanceVariation
        delay = noise.delay * configuration.particleDelay
        lifetime = max(configuration.particleLifetime + noise.lifetime * configuration.particleLifetimeVariation, 0.01)
        baseDiameter = configuration.particleSize + noise.size * configuration.particleSizeVariation
        sizeShrink = configuration.particleSizeShrink
        fadeStart = min(max(configuration.fadeStart + noise.fade * configuration.fadeStartVariation, 0), 0.99)
        fadeExponent = max(configuration.particleFadeExponent, 0.01)
        ageEasePower = max(configuration.particleAgeEasePower, 0.01)
    }

    func sample(progress: CGFloat) -> DissolveParticleSample? {
        let age = min(max((progress - delay) / lifetime, 0), 1)
        guard progress >= delay, age < 1 else { return nil }
        let diameter = max(0, baseDiameter * (1 - age * sizeShrink))
        guard diameter > 0 else { return nil }
        let fadeProgress = max(0, (age - fadeStart) / (1 - fadeStart))
        let opacity = Double(pow(1 - fadeProgress, fadeExponent))
        guard opacity > 0 else { return nil }
        return DissolveParticleSample(
            distance: distance, easedAge: 1 - pow(1 - age, ageEasePower), diameter: diameter, opacity: opacity,
        )
    }
}

struct CardActivationParticlePlan {
    let motion: DissolveParticleParameters
    let color: Color
    private let origin: CGPoint
    private let end: CGPoint
    private let control: CGPoint

    init(
        particle: CardActivationParticle,
        keywords: [Keyword],
        cardSize: CGSize,
        canvasSize: CGSize,
        configuration: CardDissolveConfiguration,
    ) {
        motion = DissolveParticleParameters(configuration: configuration, noise: particle.motionNoise)
        let index = min(Int(particle.colorNoise * CGFloat(keywords.count)), keywords.count - 1)
        color = keywords[index].visualStyle.color
        origin = CGPoint(
            x: canvasSize.width / 2 + (particle.originXNoise - 0.5) * cardSize.width * configuration.particleOriginSpread,
            y: canvasSize.height / 2 + (particle.originYNoise - 0.5) * cardSize.height * configuration.particleOriginSpread,
        )
        let curve = (particle.curveNoise - 0.5) * motion.distance * configuration.particleCurve
        let perpendicular = CGVector(dx: -particle.vector.dy, dy: particle.vector.dx)
        let pathControl = min(max(configuration.particlePathControl, 0), 1)
        end = CGPoint(
            x: origin.x + particle.vector.dx * motion.distance,
            y: origin.y + particle.vector.dy * motion.distance,
        )
        control = CGPoint(
            x: origin.x + particle.vector.dx * motion.distance * pathControl + perpendicular.dx * curve,
            y: origin.y + particle.vector.dy * motion.distance * pathControl + perpendicular.dy * curve,
        )
    }

    func position(progress: CGFloat) -> CGPoint {
        let remaining = 1 - progress
        return CGPoint(
            x: remaining * remaining * origin.x + 2 * remaining * progress * control.x + progress * progress * end.x,
            y: remaining * remaining * origin.y + 2 * remaining * progress * control.y + progress * progress * end.y,
        )
    }
}

final class CardActivationParticlePlanCache {
    private struct Key: Equatable {
        let particles: [CardActivationParticle]
        let keywords: [Keyword]
        let cardSize: CGSize
        let canvasSize: CGSize
        let configuration: CardDissolveConfiguration
    }

    private var key: Key?
    private var prepared: [CardActivationParticlePlan] = []

    func plan(
        particles: [CardActivationParticle], keywords: [Keyword], cardSize: CGSize, canvasSize: CGSize,
        configuration: CardDissolveConfiguration,
    ) -> [CardActivationParticlePlan] {
        let key = Key(particles: particles, keywords: keywords, cardSize: cardSize, canvasSize: canvasSize, configuration: configuration)
        guard self.key != key else { return prepared }
        prepared = keywords.isEmpty ? [] : particles.map {
            CardActivationParticlePlan(
                particle: $0,
                keywords: keywords,
                cardSize: cardSize,
                canvasSize: canvasSize,
                configuration: configuration,
            )
        }
        self.key = key
        return prepared
    }
}
