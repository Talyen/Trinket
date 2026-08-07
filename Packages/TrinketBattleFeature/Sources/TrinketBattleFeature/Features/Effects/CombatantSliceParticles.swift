import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

/// Border-spawned dissolve sparks along each half's outer silhouette and cut face.
struct SliceBorderParticle: Identifiable {
    let id: Int
    let origin: CGPoint
    let direction: CGVector
    let delayNoise: CGFloat
    let lifetimeNoise: CGFloat
    let distanceNoise: CGFloat
    let sizeNoise: CGFloat
    let fadeNoise: CGFloat

    /// Builds sparks for one half: visible rectangular edges plus the diagonal cut.
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
                geometry: geometry
            ) else { continue }
            particles.append(
                makeParticle(
                    index: index,
                    salt: salt,
                    origin: sample.origin,
                    outward: sample.outward
                )
            )
        }
        return particles
    }

    private struct HalfEdgeGeometry {
        let alongCut: CGVector
        let cutNormal: CGVector
        let halfSign: CGFloat
        let aspectW: CGFloat = 192
        let aspectH: CGFloat = 256
        let diagUnit: CGFloat

        init(isPrimary: Bool) {
            let angle = CombatantSliceGeometry.angleRadians
            alongCut = CGVector(dx: sin(angle), dy: cos(angle))
            cutNormal = CGVector(dx: cos(angle), dy: -sin(angle))
            // Match DiagonalSliceMask: primary occupies the -normal half-plane.
            halfSign = isPrimary ? -1 : 1
            diagUnit = hypot(aspectW, aspectH)
        }
    }

    private struct EdgeSample {
        let origin: CGPoint
        let outward: CGVector
    }

    private static func edgeSample(
        edge: Int,
        along: CGFloat,
        geometry: HalfEdgeGeometry
    ) -> EdgeSample? {
        if edge == 4 {
            // Unit-space point on the pixel-space diagonal (texture aspect).
            let span = (along - 0.5) * geometry.diagUnit * 0.95
            let origin = CGPoint(
                x: 0.5 + geometry.alongCut.dx * span / geometry.aspectW,
                y: 0.5 + geometry.alongCut.dy * span / geometry.aspectH
            )
            guard origin.x >= 0.02, origin.x <= 0.98,
                  origin.y >= 0.02, origin.y <= 0.98
            else { return nil }
            return EdgeSample(
                origin: origin,
                outward: CGVector(
                    dx: geometry.cutNormal.dx * geometry.halfSign,
                    dy: geometry.cutNormal.dy * geometry.halfSign
                )
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
        // Keep only outer-edge samples that sit on this half's silhouette.
        let side = (origin.x - 0.5) * geometry.cutNormal.dx * geometry.aspectW
            + (origin.y - 0.5) * geometry.cutNormal.dy * geometry.aspectH
        guard side * geometry.halfSign >= 0 else { return nil }
        return EdgeSample(origin: origin, outward: outward)
    }

    private static func makeParticle(
        index: Int,
        salt: Int,
        origin: CGPoint,
        outward: CGVector
    ) -> Self {
        // Wide cone around the outward normal so sparks spray off the rim.
        let tangent = CGVector(dx: -outward.dy, dy: outward.dx)
        let spray = (CombatantCardEffectNoise.value(index + salt, salt: 29) - 0.5) * 1.6
        let inward = CombatantCardEffectNoise.value(index + salt, salt: 31) * 0.35
        var dx = outward.dx * (1 - inward) + tangent.dx * spray
        var dy = outward.dy * (1 - inward) + tangent.dy * spray
        // Occasional fully free direction for "all directions" variety.
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
            fadeNoise: CombatantCardEffectNoise.value(index + salt, salt: 71)
        )
    }
}

struct SliceBorderParticles: View {
    let progress: CGFloat
    let cardSize: CGSize
    let particles: [SliceBorderParticle]
    var configuration = CardCastEffectConfiguration()

    var body: some View {
        GeometryReader { geometry in
            let origin = CGPoint(
                x: (geometry.size.width - cardSize.width) * 0.5,
                y: (geometry.size.height - cardSize.height) * 0.5
            )
            ZStack {
                ForEach(particles) { particle in
                    let sample = sample(for: particle, cardOrigin: origin)
                    Circle()
                        .fill(Keyword.bleed.visualStyle.color)
                        .frame(width: sample.diameter, height: sample.diameter)
                        .position(sample.center)
                        .opacity(sample.opacity)
                }
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
            y: cardOrigin.y + particle.origin.y * cardSize.height
        )
        let center = CGPoint(
            x: start.x + particle.direction.dx * distance * easedAge,
            y: start.y + particle.direction.dy * distance * easedAge
        )
        let diameter = max(
            0,
            (configuration.particleSize + particle.sizeNoise * configuration.particleSizeVariation)
                * (1 - age * configuration.particleSizeShrink)
        )
        let fadeStart = min(
            max(configuration.fadeStart + particle.fadeNoise * configuration.fadeStartVariation, 0),
            0.99
        )
        let fadeProgress = max(0, (age - fadeStart) / (1 - fadeStart))
        let opacity = progress >= delay && age < 1
            ? pow(1 - fadeProgress, max(configuration.particleFadeExponent, 0.01))
            : 0
        return Sample(center: center, diameter: diameter, opacity: opacity)
    }
}

/// Red sparks emitted directly along the diagonal cut line as the card splits open.
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
                delay: delay, speed: speed, size: size, lifetime: lifetime
            )
        }
    }
}

struct SliceCutParticles: View {
    let rawSplitProgress: CGFloat
    let cardSize: CGSize
    let particles: [SliceCutParticle]

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)
            let angle = CombatantSliceGeometry.angleRadians
            let along = CGVector(dx: sin(angle), dy: cos(angle))
            let normal = CGVector(dx: cos(angle), dy: -sin(angle))
            let diagLen = hypot(cardSize.width, cardSize.height)

            ZStack {
                ForEach(particles) { particle in
                    let age = (rawSplitProgress - particle.delay) / particle.lifetime
                    if age > 0, age < 1 {
                        let easedAge = 1 - pow(1 - age, 2)
                        let originX = center.x + along.dx * particle.linePosition * diagLen * 0.5
                        let originY = center.y + along.dy * particle.linePosition * diagLen * 0.5
                        let sprayDx = normal.dx * particle.side + along.dx * particle.sprayAngle
                        let sprayDy = normal.dy * particle.side + along.dy * particle.sprayAngle
                        let dist = particle.speed * easedAge

                        Circle()
                            .fill(Keyword.bleed.visualStyle.color)
                            .frame(
                                width: particle.size * (1 - 0.3 * age),
                                height: particle.size * (1 - 0.3 * age)
                            )
                            .position(x: originX + sprayDx * dist, y: originY + sprayDy * dist)
                            .opacity(Double(pow(1 - age, 1.4)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
