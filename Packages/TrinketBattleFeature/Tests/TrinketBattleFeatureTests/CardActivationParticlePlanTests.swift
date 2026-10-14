import SwiftUI
import Testing
import TrinketCore
import TrinketDesignSystem
@testable import TrinketBattleFeature

struct CardActivationParticlePlanTests {
    @Test @MainActor func `cached activation trajectories preserve samples after geometry color and configuration changes`() throws {
        let cache = CardActivationParticlePlanCache()
        let particles = CardActivationParticle.castParticles
        var varied = CardDissolveConfiguration()
        varied.particleDistanceVariation = 50
        varied.particleCurve = 0.7
        varied.particlePathControl = 0.71
        varied.fadeStartVariation = 0.2
        let keywordSets: [[Keyword]] = [[.physical], [.holy, .burn]]
        let progresses: [CGFloat] = [0, 0.08, 0.25, 0.5, 0.9, 1]
        for configuration in [CardDissolveConfiguration(), varied] {
            for size in [CGSize(width: 192, height: 256), CGSize(width: 137, height: 201)] {
                let canvas = CGSize(width: size.width + 480, height: size.height + 480)
                for keywords in keywordSets {
                    let plan = cache.plan(
                        particles: particles,
                        keywords: keywords,
                        cardSize: size,
                        canvasSize: canvas,
                        configuration: configuration,
                    )
                    for (particle, prepared) in zip(particles, plan) {
                        let colorIndex = min(Int(particle.colorNoise * CGFloat(keywords.count)), keywords.count - 1)
                        #expect(prepared.color == keywords[colorIndex].visualStyle.color)
                        for progress in progresses {
                            let expected = referenceSample(
                                particle,
                                progress: progress,
                                cardSize: size,
                                canvasSize: canvas,
                                configuration: configuration,
                            )
                            let motion = prepared.motion.sample(progress: progress)
                            guard let expected else {
                                #expect(motion == nil)
                                continue
                            }
                            let actual = try #require(motion)
                            #expect(prepared.position(progress: actual.easedAge) == expected.center)
                            #expect(actual.diameter == expected.diameter)
                            #expect(actual.opacity == expected.opacity)
                        }
                    }
                }
            }
        }
        #expect(cache.plan(particles: particles, keywords: [], cardSize: .zero, canvasSize: .zero, configuration: varied).isEmpty)
    }

    /// Frozen pre-cache equations: keep operation order to detect trajectory and sampling changes.
    private func referenceSample(
        _ particle: CardActivationParticle, progress: CGFloat, cardSize: CGSize, canvasSize: CGSize,
        configuration c: CardDissolveConfiguration,
    ) -> (center: CGPoint, diameter: CGFloat, opacity: Double)? {
        let noise = particle.motionNoise
        let delay = noise.delay * c.particleDelay
        let lifetime = max(c.particleLifetime + noise.lifetime * c.particleLifetimeVariation, 0.01)
        let age = min(max((progress - delay) / lifetime, 0), 1)
        guard progress >= delay, age < 1 else { return nil }
        let diameter = max(0, (c.particleSize + noise.size * c.particleSizeVariation) * (1 - age * c.particleSizeShrink))
        guard diameter > 0 else { return nil }
        let fadeStart = min(max(c.fadeStart + noise.fade * c.fadeStartVariation, 0), 0.99)
        let fadeProgress = max(0, (age - fadeStart) / (1 - fadeStart))
        let opacity = Double(pow(1 - fadeProgress, max(c.particleFadeExponent, 0.01)))
        guard opacity > 0 else { return nil }
        let distance = c.particleDistance + noise.distance * c.particleDistanceVariation
        let easedAge = 1 - pow(1 - age, max(c.particleAgeEasePower, 0.01))
        let curve = (particle.curveNoise - 0.5) * distance * c.particleCurve
        let origin = CGPoint(
            x: canvasSize.width / 2 + (particle.originXNoise - 0.5) * cardSize.width * c.particleOriginSpread,
            y: canvasSize.height / 2 + (particle.originYNoise - 0.5) * cardSize.height * c.particleOriginSpread,
        )
        let vector = particle.vector
        let perpendicular = CGVector(dx: -vector.dy, dy: vector.dx)
        let pathControl = min(max(c.particlePathControl, 0), 1)
        let end = CGPoint(x: origin.x + vector.dx * distance, y: origin.y + vector.dy * distance)
        let control = CGPoint(
            x: origin.x + vector.dx * distance * pathControl + perpendicular.dx * curve,
            y: origin.y + vector.dy * distance * pathControl + perpendicular.dy * curve,
        )
        let remaining = 1 - easedAge
        return (
            center: CGPoint(
                x: remaining * remaining * origin.x + 2 * remaining * easedAge * control.x + easedAge * easedAge * end.x,
                y: remaining * remaining * origin.y + 2 * remaining * easedAge * control.y + easedAge * easedAge * end.y,
            ),
            diameter: diameter, opacity: opacity,
        )
    }
}
