import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct CardActivationParticles: View {
    let progress: CGFloat
    let keywords: [Keyword]
    let cardSize: CGSize
    let particles: [CardActivationParticle]
    var configuration = CardCastEffectConfiguration()

    var body: some View {
        Canvas { context, size in
            guard !keywords.isEmpty else { return }
            for particle in particles {
                let sample = sample(for: particle, size: size)
                guard sample.opacity > 0, sample.diameter > 0 else { continue }
                let rect = CGRect(
                    x: sample.center.x - sample.diameter / 2,
                    y: sample.center.y - sample.diameter / 2,
                    width: sample.diameter,
                    height: sample.diameter,
                )
                var particleContext = context
                particleContext.opacity = sample.opacity
                particleContext.fill(
                    Path(ellipseIn: rect),
                    with: .color(keywordColor(for: particle)),
                )
            }
        }
        .allowsHitTesting(false)
    }

    private struct Sample {
        let center: CGPoint
        let diameter: CGFloat
        let opacity: Double
    }

    private func sample(for particle: CardActivationParticle, size: CGSize) -> Sample {
        let distance = configuration.particleDistance
            + particle.distanceNoise * configuration.particleDistanceVariation
        let delay = particle.delayNoise * configuration.particleDelay
        let lifetime = configuration.particleLifetime
            + particle.lifetimeNoise * configuration.particleLifetimeVariation
        let age = min(max((progress - delay) / lifetime, 0), 1)
        let easedAge = 1 - pow(1 - age, max(configuration.particleAgeEasePower, 0.01))
        let curve = (particle.curveNoise - 0.5) * distance * configuration.particleCurve
        let center = curvedPosition(
            from: particleOrigin(particle, size: size),
            vector: particle.vector,
            distance: distance,
            curve: curve,
            progress: easedAge,
        )
        let diameter = max(
            0,
            (configuration.particleSize + particle.sizeNoise * configuration.particleSizeVariation)
                * (1 - age * configuration.particleSizeShrink),
        )
        let fadeStart = min(
            max(configuration.fadeStart + particle.fadeNoise * configuration.fadeStartVariation, 0),
            0.99,
        )
        let fadeProgress = max(0, (age - fadeStart) / (1 - fadeStart))
        let opacity = progress >= delay && age < 1
            ? pow(1 - fadeProgress, max(configuration.particleFadeExponent, 0.01))
            : 0
        return Sample(center: center, diameter: diameter, opacity: opacity)
    }

    private func keywordColor(for particle: CardActivationParticle) -> Color {
        let index = min(Int(particle.colorNoise * CGFloat(keywords.count)), keywords.count - 1)
        return keywords[index].visualStyle.color
    }

    private func particleOrigin(_ particle: CardActivationParticle, size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2 + (particle.originXNoise - 0.5)
                * cardSize.width * configuration.particleOriginSpread,
            y: size.height / 2 + (particle.originYNoise - 0.5)
                * cardSize.height * configuration.particleOriginSpread,
        )
    }

    private func curvedPosition(
        from origin: CGPoint,
        vector: CGVector,
        distance: CGFloat,
        curve: CGFloat,
        progress: CGFloat,
    ) -> CGPoint {
        let perpendicular = CGVector(dx: -vector.dy, dy: vector.dx)
        let pathControl = min(max(configuration.particlePathControl, 0), 1)
        let end = CGPoint(
            x: origin.x + vector.dx * distance,
            y: origin.y + vector.dy * distance,
        )
        let control = CGPoint(
            x: origin.x + vector.dx * distance * pathControl + perpendicular.dx * curve,
            y: origin.y + vector.dy * distance * pathControl + perpendicular.dy * curve,
        )
        let remaining = 1 - progress
        return CGPoint(
            x: remaining * remaining * origin.x
                + 2 * remaining * progress * control.x
                + progress * progress * end.x,
            y: remaining * remaining * origin.y
                + 2 * remaining * progress * control.y
                + progress * progress * end.y,
        )
    }
}
