import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

#if DEBUG
// DEBUG playground only — production motion lives in recipe/config types. Do not ship lab UI.

enum CombatantDeathEffectKind: String, CaseIterable, Identifiable {
    case slice
    case dissolveBaseline

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .slice: "Slice"
        case .dissolveBaseline: "Dissolve Baseline"
        }
    }
}

struct CombatantDeathEffectConfig: Equatable {
    var intensity: CGFloat = 1
    var particleCount: Int = 24
    var tintStrength: CGFloat = 0.2
    var speed: CGFloat = 1

    /// Separation between halves as a fraction of card width.
    var splitGap: CGFloat = 0.22
    /// Hold before halves begin to separate (0…1 of the clip).
    var splitDelay: CGFloat = 0.18
    /// Celebrate dissolve with gold/holy fireworks (Dissolve Baseline).
    var celebrateDissolve = true

    static func defaults(for kind: CombatantDeathEffectKind) -> Self {
        var config = Self()
        switch kind {
        case .slice:
            config.intensity = 0.5
            config.splitGap = 0.22
            config.splitDelay = 0.2
            config.particleCount = 48
            config.tintStrength = 0.85
        case .dissolveBaseline:
            config.celebrateDissolve = true
            config.particleCount = 28
        }
        return config
    }
}

struct CombatantDeathEffect<Content: View>: View {
    let kind: CombatantDeathEffectKind
    let config: CombatantDeathEffectConfig
    let progress: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            switch kind {
            case .slice:
                slice(size: size)
            case .dissolveBaseline:
                dissolveBaseline(size: size)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard kind == .slice else { return }
            CardDissolveTexture.prewarm()
        }
        .task(id: kind) {
            guard kind == .slice else { return }
            // Bake dissolve masks before the mid-clip transition so the first
            // threshold step never stalls the display link (which froze motion).
            await CardDissolveTexture.prepare()
        }
    }

    private var effectiveProgress: CGFloat {
        min(max(progress * config.speed, 0), 1)
    }

    private func slice(size: CGSize) -> some View {
        let delay = min(max(config.splitDelay, 0), 0.6)
        let p = effectiveProgress
        let rawSplitT = delay >= 1 ? 0 : min(max((p - delay) / (1 - delay), 0), 1)
        // Fast, smooth ease-out separation after cut line finishes so halves break apart
        // responsively without a linear jerk or sudden view branch swap.
        let splitT = 1 - pow(1 - rawSplitT, 3)
        let gap = size.width * config.splitGap * splitT * config.intensity
        let lift = size.height * 0.08 * splitT * config.intensity
        let twist = 7.0 * Double(splitT * config.intensity)
        let dissolveStart: CGFloat = 0.42
        let dissolveLinear = dissolveStart >= 1
            ? 0
            : min(max((p - dissolveStart) / (1 - dissolveStart), 0), 1)
        // Slow start, then accelerate — applied only to wipe/particles, not motion.
        let dissolveEased = pow(dissolveLinear, 2.2)
        let halfParticles = max(config.particleCount / 2, 16)
        let radians = CombatantSliceGeometry.angleRadians
        let normal = CGVector(dx: cos(radians), dy: -sin(radians))
        let leftParticles = SliceBorderParticle.make(count: halfParticles)
        let rightParticles = SliceBorderParticle.make(count: halfParticles, salt: 40)
        let cutParticles = SliceCutParticle.make(count: max(config.particleCount, 32))

        return ZStack {
            slicedHalf(
                size: size,
                isPrimary: true,
                dissolveProgress: dissolveEased,
                particles: leftParticles
            )
            .offset(
                x: -normal.dx * gap / 2,
                y: -normal.dy * gap / 2 - lift
            )
            .rotationEffect(.degrees(-twist), anchor: .center)

            slicedHalf(
                size: size,
                isPrimary: false,
                dissolveProgress: dissolveEased,
                particles: rightParticles
            )
            .offset(
                x: normal.dx * gap / 2,
                y: normal.dy * gap / 2 + lift
            )
            .rotationEffect(.degrees(twist), anchor: .center)

            sliceFlashOverlay(size: size, progress: p, delay: delay)

            SliceCutParticles(
                rawSplitProgress: rawSplitT,
                cardSize: size,
                particles: cutParticles
            )
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func sliceFlashOverlay(
        size: CGSize,
        progress p: CGFloat,
        delay: CGFloat
    ) -> some View {
        // Hold the drawn line through the cut, then fade once halves start moving.
        let draw = min(max(p / max(delay, 0.001), 0), 1)
        let fade = 1 - min(max((p - delay) / 0.18, 0), 1)
        let lineOpacity = Double(fade) * Double(max(config.intensity, 0.35))
            * (0.55 + Double(config.tintStrength) * 0.7)
        if lineOpacity > 0.02, draw > 0 {
            Canvas { context, canvasSize in
                drawSliceLine(
                    in: &context,
                    size: canvasSize,
                    drawProgress: draw,
                    intensity: CGFloat(lineOpacity)
                )
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
        }
    }

    /// Solid drifting half + dissolve layer share one offset parent so wipe
    /// activation never remounts or stalls separation motion.
    private func slicedHalf(
        size: CGSize,
        isPrimary: Bool,
        dissolveProgress: CGFloat,
        particles: [SliceBorderParticle]
    ) -> some View {
        let dissolveConfig = CardCastEffectConfiguration.sliceHalfDissolve
        let travelPad = dissolveConfig.particleDistance
            + dissolveConfig.particleDistanceVariation
            + 40
        // Crossfade solid → masked wipe so we never hit BattleDissolveEffect's
        // unmasked→masked view swap (that bake hitch paused the TimelineView).
        let solidOpacity = Double(1 - min(dissolveProgress / 0.18, 1))
        let wipeOpacity = dissolveProgress > 0 ? 1.0 : 0.0
        let wipeProgress = max(dissolveProgress, 0.025)

        return ZStack {
            halfCardContent(size: size, isPrimary: isPrimary)
                .opacity(solidOpacity)

            halfCardContent(size: size, isPrimary: isPrimary)
                .mask {
                    CardDissolveThresholdMask(
                        progress: wipeProgress,
                        edgeDepthWeight: dissolveConfig.dissolveEdgeDepthWeight,
                        noiseWeight: dissolveConfig.dissolveNoiseWeight,
                        cellSize: Int(dissolveConfig.dissolveCellSize.rounded()),
                        thresholdMidpoint: dissolveConfig.dissolveThresholdMidpoint,
                        thresholdContrast: dissolveConfig.dissolveThresholdContrast
                    )
                }
                .compositingGroup()
                .opacity(wipeOpacity)

            // Particles wait until dissolve begins; emit from card borders outward.
            if dissolveProgress > 0.001 {
                SliceBorderParticles(
                    progress: dissolveProgress,
                    cardSize: size,
                    particles: particles,
                    configuration: dissolveConfig
                )
                .frame(width: size.width + travelPad * 2, height: size.height + travelPad * 2)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func halfCardContent(size: CGSize, isPrimary: Bool) -> some View {
        content()
            .frame(width: size.width, height: size.height)
            .clipShape(TrinketDesign.cardShape)
            .mask(
                DiagonalSliceMask(
                    isPrimary: isPrimary,
                    angleDegrees: CombatantSliceGeometry.angleDegrees
                )
                .frame(width: size.width, height: size.height)
            )
    }

    private func dissolveBaseline(size: CGSize) -> some View {
        let particles = CardActivationParticle.make(
            count: config.particleCount,
            spread: config.celebrateDissolve ? .fireworks : .radial
        )
        let keywords: [Keyword] = config.celebrateDissolve ? [.gold, .holy] : [.physical]
        let configuration: CardCastEffectConfiguration = config.celebrateDissolve
            ? .defeatCelebration
            : CardCastEffectConfiguration()

        return BattleDissolveEffect(
            progress: effectiveProgress,
            keywords: keywords,
            size: size,
            particles: particles,
            configuration: configuration
        ) {
            content()
                .frame(width: size.width, height: size.height)
                .clipShape(TrinketDesign.cardShape)
        }
    }
}

/// Cut angle from vertical for Slice (negative = lean left).
private enum CombatantSliceGeometry {
    static let angleDegrees: CGFloat = -30
    static var angleRadians: CGFloat {
        angleDegrees * .pi / 180
    }
}

/// Half-plane on one side of a diagonal cut through the card center.
private struct DiagonalSliceMask: Shape {
    var isPrimary: Bool
    var angleDegrees: CGFloat

    func path(in rect: CGRect) -> Path {
        let angle = angleDegrees * .pi / 180
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Along the cut (top→bottom when angle is 0).
        let along = CGVector(dx: sin(angle), dy: cos(angle))
        let normal = CGVector(dx: cos(angle), dy: -sin(angle))
        let extent = max(rect.width, rect.height) * 2.2
        let a = CGPoint(x: center.x - along.dx * extent, y: center.y - along.dy * extent)
        let b = CGPoint(x: center.x + along.dx * extent, y: center.y + along.dy * extent)
        let sign: CGFloat = isPrimary ? -1 : 1
        let c = CGPoint(x: b.x + normal.dx * extent * sign, y: b.y + normal.dy * extent * sign)
        let d = CGPoint(x: a.x + normal.dx * extent * sign, y: a.y + normal.dy * extent * sign)
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: c)
        path.addLine(to: d)
        path.closeSubpath()
        return path
    }
}

private extension CardCastEffectConfiguration {
    /// Late-window half dissolve for Slice — ease is applied by the caller so
    /// dissolve starts slow and accelerates; shrink stays 0 so halves keep sliding.
    static let sliceHalfDissolve = CardCastEffectConfiguration(
        dissolveDuration: 1, dissolveShrink: 0, particleDistance: 110, particleDistanceVariation: 50,
        particleDelay: 0.12, particleLifetime: 0.55, particleLifetimeVariation: 0.2, particleCurve: 0.85,
        particleOriginSpread: 1, particleSize: 3.0, particleSizeVariation: 2.6, fadeStart: 0.2,
        particleAgeEasePower: 1.8, particleSizeShrink: 0.4, particleFadeExponent: 1.3, particlePathControl: 0.35
    )
}

/// Progressive grey/white cut line drawn from one end of the slice to the other.
private func drawSliceLine(
    in context: inout GraphicsContext,
    size: CGSize,
    drawProgress: CGFloat,
    intensity: CGFloat
) {
    let lineStyle = Keyword.physical.visualStyle
    let angleRadians = CombatantSliceGeometry.angleRadians
    let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
    let along = CGVector(dx: sin(angleRadians), dy: cos(angleRadians))
    // Cover the full card diagonal so the stroke reads as a complete slice.
    let halfLen = hypot(size.width, size.height) * 0.55
    // Ease the tip so the early draw is readable, then finishes into the cut.
    let lead = 1 - pow(1 - min(max(drawProgress, 0), 1), 1.55)

    let start = CGPoint(
        x: center.x - along.dx * halfLen,
        y: center.y - along.dy * halfLen
    )
    let tip = CGPoint(
        x: start.x + along.dx * halfLen * 2 * lead,
        y: start.y + along.dy * halfLen * 2 * lead
    )

    var streak = Path()
    streak.move(to: start)
    streak.addLine(to: tip)
    context.stroke(
        streak,
        with: .color(lineStyle.secondaryColor.opacity(Double(0.95 * intensity))),
        style: StrokeStyle(lineWidth: 2.6 * intensity, lineCap: .round)
    )
    // Bright tip so the stroke reads as being drawn, not revealed all at once.
    let tipRadius = 2.2 * intensity
    let tipRect = CGRect(
        x: tip.x - tipRadius,
        y: tip.y - tipRadius,
        width: tipRadius * 2,
        height: tipRadius * 2
    )
    context.fill(
        Path(ellipseIn: tipRect),
        with: .color(lineStyle.secondaryColor.opacity(Double(intensity)))
    )
}

/// Border-spawned dissolve sparks (DEBUG slice only).
private struct SliceBorderParticle: Identifiable {
    let id: Int
    let origin: CGPoint
    let direction: CGVector
    let delayNoise: CGFloat
    let lifetimeNoise: CGFloat
    let distanceNoise: CGFloat
    let sizeNoise: CGFloat
    let fadeNoise: CGFloat

    static func make(count: Int, salt: Int = 0) -> [Self] {
        (0 ..< max(0, count)).map { index in
            let edge = (index + salt) % 4
            let along = CombatantCardEffectNoise.value(index + salt, salt: 13)
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
            // Wide cone around the outward normal so sparks spray off the rim.
            let tangent = CGVector(dx: -outward.dy, dy: outward.dx)
            let spray = (CombatantCardEffectNoise.value(index + salt, salt: 29) - 0.5) * 1.6
            let inward = CombatantCardEffectNoise.value(index + salt, salt: 31) * 0.35
            var dx = outward.dx * (1 - inward) + tangent.dx * spray
            var dy = outward.dy * (1 - inward) + tangent.dy * spray
            // Occasional fully free direction for "all directions" variety.
            if CombatantCardEffectNoise.value(index + salt, salt: 37) > 0.72 {
                let angle = CombatantCardEffectNoise.value(index + salt, salt: 41) * .pi * 2
                dx = cos(angle)
                dy = sin(angle)
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
}

private struct SliceBorderParticles: View {
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
private struct SliceCutParticle: Identifiable {
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

private struct SliceCutParticles: View {
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
                ForEach(particles) { p in
                    let age = (rawSplitProgress - p.delay) / p.lifetime
                    if age > 0, age < 1 {
                        let easedAge = 1 - pow(1 - age, 2)
                        let originX = center.x + along.dx * p.linePosition * diagLen * 0.5
                        let originY = center.y + along.dy * p.linePosition * diagLen * 0.5
                        let sprayDx = normal.dx * p.side + along.dx * p.sprayAngle
                        let sprayDy = normal.dy * p.side + along.dy * p.sprayAngle
                        let dist = p.speed * easedAge

                        Circle()
                            .fill(Keyword.bleed.visualStyle.color)
                            .frame(width: p.size * (1 - 0.3 * age), height: p.size * (1 - 0.3 * age))
                            .position(x: originX + sprayDx * dist, y: originY + sprayDy * dist)
                            .opacity(Double(pow(1 - age, 1.4)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
#endif
