import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

struct SliceBorderParticle: Identifiable {
    let id: Int
    let origin: CGPoint
    let direction: CGVector
    let delayNoise: CGFloat
    let lifetimeNoise: CGFloat
    let distanceNoise: CGFloat
    let sizeNoise: CGFloat
    let fadeNoise: CGFloat

    static func make(count: Int, salt: Int = 0, isPrimary: Bool) -> [Self] {
        let geometry = HalfEdgeGeometry(isPrimary: isPrimary)
        var particles: [Self] = []
        particles.reserveCapacity(max(0, count))
        var index = 0
        var guardLimit = max(count * 8, 1)
        while particles.count < count, guardLimit > 0 {
            defer {
                index += 1
                guardLimit -= 1
            }
            guard let sample = edgeSample(
                edge: (index + salt) % 5,
                along: CombatantCardEffectNoise.value(index + salt, salt: 13),
                geometry: geometry,
            ) else { continue }
            particles.append(
                makeParticle(
                    index: index,
                    salt: salt,
                    origin: sample.origin,
                    outward: sample.outward,
                ),
            )
        }
        return particles
    }

    private struct HalfEdgeGeometry {
        let halfSign: CGFloat

        init(isPrimary: Bool) {
            halfSign = isPrimary ? -1 : 1
        }
    }

    private struct EdgeSample {
        let origin: CGPoint
        let outward: CGVector
    }

    private static func edgeSample(
        edge: Int,
        along: CGFloat,
        geometry: HalfEdgeGeometry,
    ) -> EdgeSample? {
        if edge == 4 {
            let origin = CombatantSliceCrack.point(atFraction: along)
            guard origin.x >= 0.02, origin.x <= 0.98,
                  origin.y >= 0.02, origin.y <= 0.98
            else { return nil }
            let tangent = CombatantSliceCrack.tangent(atFraction: along)
            return EdgeSample(
                origin: origin,
                outward: CGVector(
                    dx: tangent.dy * geometry.halfSign,
                    dy: -tangent.dx * geometry.halfSign,
                ),
            )
        }

        let origin: CGPoint
        let outward: CGVector
        switch edge {
        case 0:
            origin = CGPoint(x: along, y: 0.02)
            outward = CGVector(dx: 0, dy: -1)
        case 1:
            origin = CGPoint(x: 0.98, y: along)
            outward = CGVector(dx: 1, dy: 0)
        case 2:
            origin = CGPoint(x: along, y: 0.98)
            outward = CGVector(dx: 0, dy: 1)
        default:
            origin = CGPoint(x: 0.02, y: along)
            outward = CGVector(dx: -1, dy: 0)
        }
        guard CombatantSliceCrack.side(of: origin) * geometry.halfSign >= 0 else { return nil }
        return EdgeSample(origin: origin, outward: outward)
    }

    private static func makeParticle(
        index: Int,
        salt: Int,
        origin: CGPoint,
        outward: CGVector,
    ) -> Self {
        let tangent = CGVector(dx: -outward.dy, dy: outward.dx)
        let spray = (CombatantCardEffectNoise.value(index + salt, salt: 29) - 0.5) * 1.6
        let inward = CombatantCardEffectNoise.value(index + salt, salt: 31) * 0.35
        var dx = outward.dx * (1 - inward) + tangent.dx * spray
        var dy = outward.dy * (1 - inward) + tangent.dy * spray
        if CombatantCardEffectNoise.value(index + salt, salt: 37) > 0.72 {
            let freeAngle = CombatantCardEffectNoise.value(index + salt, salt: 41) * .pi * 2
            dx = cos(freeAngle)
            dy = sin(freeAngle)
        }
        let length = max(0.001, hypot(dx, dy))
        return Self(
            id: index + salt * 1000,
            origin: origin,
            direction: CGVector(dx: dx / length, dy: dy / length),
            delayNoise: CombatantCardEffectNoise.value(index + salt, salt: 53),
            lifetimeNoise: CombatantCardEffectNoise.value(index + salt, salt: 59),
            distanceNoise: CombatantCardEffectNoise.value(index + salt, salt: 61),
            sizeNoise: CombatantCardEffectNoise.value(index + salt, salt: 67),
            fadeNoise: CombatantCardEffectNoise.value(index + salt, salt: 71),
        )
    }
}

struct SliceBorderParticles: View {
    let progress: CGFloat
    let cardSize: CGSize
    let particles: [SliceBorderParticle]
    var configuration = CardCastEffectConfiguration()

    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(
                x: (size.width - cardSize.width) * 0.5,
                y: (size.height - cardSize.height) * 0.5,
            )
            let color = TrinketDesign.Colors.battleSliceSpark
            for particle in particles {
                let sample = sample(for: particle, cardOrigin: origin)
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
                    with: .color(color),
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

    private func sample(for particle: SliceBorderParticle, cardOrigin: CGPoint) -> Sample {
        let distance = configuration.particleDistance
            + particle.distanceNoise * configuration.particleDistanceVariation
        let delay = particle.delayNoise * configuration.particleDelay
        let lifetime = configuration.particleLifetime
            + particle.lifetimeNoise * configuration.particleLifetimeVariation
        let age = min(max((progress - delay) / max(lifetime, 0.01), 0), 1)
        let easedAge = 1 - pow(1 - age, max(configuration.particleAgeEasePower, 0.01))
        let start = CGPoint(
            x: cardOrigin.x + particle.origin.x * cardSize.width,
            y: cardOrigin.y + particle.origin.y * cardSize.height,
        )
        let center = CGPoint(
            x: start.x + particle.direction.dx * distance * easedAge,
            y: start.y + particle.direction.dy * distance * easedAge,
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
}

struct SliceCutParticle: Identifiable {
    let id: Int
    let linePosition: CGFloat
    let side: CGFloat
    let sprayAngle: CGFloat
    let delay: CGFloat
    let speed: CGFloat
    let size: CGFloat
    let lifetime: CGFloat

    static func make(count: Int) -> [Self] {
        (0 ..< count).map { index in
            let pos = (CombatantCardEffectNoise.value(index, salt: 101) - 0.5) * 1.3
            let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let spray = (CombatantCardEffectNoise.value(index, salt: 107) - 0.5) * 0.8
            let delay = CombatantCardEffectNoise.value(index, salt: 113) * 0.12
            let speed = 45 + CombatantCardEffectNoise.value(index, salt: 127) * 95
            let size = 2.5 + CombatantCardEffectNoise.value(index, salt: 131) * 3.5
            let lifetime = 0.35 + CombatantCardEffectNoise.value(index, salt: 139) * 0.35
            return Self(
                id: index, linePosition: pos, side: side, sprayAngle: spray,
                delay: delay, speed: speed, size: size, lifetime: lifetime,
            )
        }
    }
}

struct SliceCutParticles: View {
    let crackProgress: CGFloat
    let cardSize: CGSize
    let particles: [SliceCutParticle]

    var body: some View {
        Canvas { context, _ in
            let color = TrinketDesign.Colors.battleSliceSpark

            for particle in particles {
                let age = (crackProgress - particle.delay) / particle.lifetime
                guard age > 0, age < 1 else { continue }
                let easedAge = 1 - pow(1 - age, 2)
                let cardSpan = CombatantSliceCrack.cardFractionRange
                let spanFraction = (particle.linePosition + 0.65) / 1.3
                let fraction = cardSpan.lowerBound + spanFraction * (cardSpan.upperBound - cardSpan.lowerBound)
                let origin = CombatantSliceCrack.point(atFraction: fraction, size: cardSize)
                let tangent = CombatantSliceCrack.tangent(atFraction: fraction)
                let localNormal = CGVector(dx: tangent.dy, dy: -tangent.dx)
                let sprayDx = localNormal.dx * particle.side + tangent.dx * particle.sprayAngle
                let sprayDy = localNormal.dy * particle.side + tangent.dy * particle.sprayAngle
                let dist = particle.speed * easedAge
                let diameter = particle.size * (1 - 0.3 * age)
                guard diameter > 0 else { continue }
                let opacity = Double(pow(1 - age, 1.4))
                guard opacity > 0 else { continue }

                let posX = origin.x + sprayDx * dist
                let posY = origin.y + sprayDy * dist
                let rect = CGRect(
                    x: posX - diameter / 2,
                    y: posY - diameter / 2,
                    width: diameter,
                    height: diameter,
                )
                var particleContext = context
                particleContext.opacity = opacity
                particleContext.fill(
                    Path(ellipseIn: rect),
                    with: .color(color),
                )
            }
        }
        .allowsHitTesting(false)
    }
}
