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
    }

    private var effectiveProgress: CGFloat {
        min(max(progress * config.speed, 0), 1)
    }

    private func slice(size: CGSize) -> some View {
        let delay = min(max(config.splitDelay, 0), 0.6)
        let p = effectiveProgress
        let splitT = delay >= 1 ? 0 : min(max((p - delay) / (1 - delay), 0), 1)
        // Linear separation so halves keep drifting through the dissolve window
        // (a decelerating ease made late motion look frozen).
        let gap = size.width * config.splitGap * splitT * config.intensity
        let lift = size.height * 0.08 * splitT * config.intensity
        let twist = 7.0 * Double(splitT * config.intensity)
        let dissolveStart: CGFloat = 0.48
        let dissolveLocal = dissolveStart >= 1
            ? 0
            : min(max((p - dissolveStart) / (1 - dissolveStart), 0), 1)
        let halfParticles = max(config.particleCount / 2, 16)
        let radians = CombatantSliceGeometry.angleRadians
        // Outward normal to the cut (halves separate along this axis).
        let normal = CGVector(dx: cos(radians), dy: -sin(radians))

        return ZStack {
            if splitT <= 0 {
                content()
                    .frame(width: size.width, height: size.height)
                    .clipShape(TrinketDesign.cardShape)
            } else {
                dissolvingHalf(
                    size: size,
                    isPrimary: true,
                    dissolveProgress: dissolveLocal,
                    particles: CardActivationParticle.make(count: halfParticles, spread: .radial)
                )
                .offset(
                    x: -normal.dx * gap / 2,
                    y: -normal.dy * gap / 2 - lift
                )
                .rotationEffect(.degrees(-twist), anchor: .center)

                dissolvingHalf(
                    size: size,
                    isPrimary: false,
                    dissolveProgress: dissolveLocal,
                    particles: CardActivationParticle.make(count: halfParticles, spread: .radial)
                )
                .offset(
                    x: normal.dx * gap / 2,
                    y: normal.dy * gap / 2 + lift
                )
                .rotationEffect(.degrees(twist), anchor: .center)
            }

            sliceFlashOverlay(size: size, progress: p, delay: delay)
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func sliceFlashOverlay(
        size: CGSize,
        progress p: CGFloat,
        delay: CGFloat
    ) -> some View {
        let crackFlash = p < delay + 0.14
            ? Double((1 - abs(p - delay) / 0.14).clamped(to: 0 ... 1)) * Double(config.tintStrength)
            : 0
        let sliceFlashWindow = max(delay, 0.08)
        let sliceLead = min(max(p / sliceFlashWindow, 0), 1)
        let sliceFade = 1 - min(max((p - delay) / 0.1, 0), 1)
        let sliceFlash = p <= delay + 0.1 ? Double(sliceLead * sliceFade) : 0
        if crackFlash > 0 || sliceFlash > 0 {
            let style = Keyword.bleed.visualStyle
            ZStack {
                if crackFlash > 0 {
                    Rectangle()
                        .fill(style.color.opacity(crackFlash))
                        .frame(width: 3 + 4 * CGFloat(crackFlash), height: size.height * 1.35)
                        .rotationEffect(.degrees(Double(CombatantSliceGeometry.angleDegrees)))
                        .blur(radius: 1.1)
                }
                if sliceFlash > 0 {
                    Canvas { context, canvasSize in
                        drawSliceFlash(
                            in: &context,
                            size: canvasSize,
                            progress: p,
                            delay: delay,
                            intensity: CGFloat(sliceFlash) * max(config.intensity, 0.35)
                                * (0.55 + config.tintStrength * 0.7),
                            particleCount: max(config.particleCount, 28),
                            style: style
                        )
                    }
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func dissolvingHalf(
        size: CGSize,
        isPrimary: Bool,
        dissolveProgress: CGFloat,
        particles: [CardActivationParticle]
    ) -> some View {
        BattleDissolveEffect(
            progress: dissolveProgress,
            keywords: [.bleed],
            size: size,
            particles: particles,
            configuration: .sliceHalfDissolve
        ) {
            halfCardContent(size: size, isPrimary: isPrimary)
        }
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
    /// Late-window half dissolve for Slice — no shrink so halves keep sliding
    /// while the face clears; denser, longer-lived particles.
    static let sliceHalfDissolve = CardCastEffectConfiguration(
        dissolveDuration: 0.78,
        dissolveShrink: 0,
        particleDistance: 130,
        particleDistanceVariation: 55,
        particleDelay: 0.02,
        particleLifetime: 0.58,
        particleLifetimeVariation: 0.18,
        particleCurve: 1.25,
        particleOriginSpread: 0.42,
        particleSize: 3.2,
        particleSizeVariation: 2.8,
        fadeStart: 0.22,
        particleAgeEasePower: 2.0,
        particleSizeShrink: 0.35,
        particleFadeExponent: 1.25,
        particlePathControl: 0.4
    )
}

/// Dark-red sparks that travel along the diagonal cut before the card splits.
private func drawSliceFlash(
    in context: inout GraphicsContext,
    size: CGSize,
    progress: CGFloat,
    delay: CGFloat,
    intensity: CGFloat,
    particleCount: Int,
    style: Keyword.VisualStyle
) {
    let angleRadians = CombatantSliceGeometry.angleRadians
    let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
    let along = CGVector(dx: sin(angleRadians), dy: cos(angleRadians))
    let normal = CGVector(dx: cos(angleRadians), dy: -sin(angleRadians))
    let halfLen = max(size.width, size.height) * 0.72
    let lead = min(max(progress / max(delay, 0.001), 0), 1)
    let leadLen = lead * halfLen * 2

    let start = CGPoint(
        x: center.x - along.dx * halfLen,
        y: center.y - along.dy * halfLen
    )
    let tip = CGPoint(
        x: start.x + along.dx * leadLen,
        y: start.y + along.dy * leadLen
    )

    var streak = Path()
    streak.move(to: start)
    streak.addLine(to: tip)
    context.stroke(
        streak,
        with: .color(style.glowColor.opacity(Double(0.75 * intensity))),
        style: StrokeStyle(lineWidth: 5 * intensity, lineCap: .round)
    )
    context.stroke(
        streak,
        with: .color(style.color.opacity(Double(0.95 * intensity))),
        style: StrokeStyle(lineWidth: 2.2 * intensity, lineCap: .round)
    )

    for index in 0 ..< particleCount {
        let noise = CombatantCardEffectNoise.value(index, salt: 61)
        let alongT = CombatantCardEffectNoise.value(index, salt: 67)
        let particleDist = alongT * halfLen * 2
        guard particleDist <= leadLen + 6 else { continue }
        let age = min(max((leadLen - particleDist) / max(halfLen * 0.45, 1), 0), 1)
        let sparkOpacity = Double((1 - age * 0.85) * intensity)
        guard sparkOpacity > 0.02 else { continue }

        let spread = (noise - 0.5) * 16 * intensity
        let point = CGPoint(
            x: start.x + along.dx * particleDist + normal.dx * spread,
            y: start.y + along.dy * particleDist + normal.dy * spread
        )
        let diameter = (2.2 + noise * 4.5) * intensity
        let rect = CGRect(
            x: point.x - diameter / 2,
            y: point.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .color(style.color.opacity(sparkOpacity))
        )
        context.fill(
            Path(ellipseIn: rect.insetBy(dx: -diameter * 0.7, dy: -diameter * 0.7)),
            with: .color(style.glowColor.opacity(sparkOpacity * 0.5))
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
#endif
