import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

/// Tunables for the enemy Slice death effect.
struct CombatantSliceEffectConfig: Equatable {
    var intensity: CGFloat = 0.5
    var particleCount: Int = 48
    var tintStrength: CGFloat = 0.85
    var speed: CGFloat = 1
    /// Final separation between halves as a fraction of card width.
    var splitGap: CGFloat = 0.22
    /// Small fissure gap opened during the crack hold, as a fraction of card width.
    var crackGap: CGFloat = 0.035
    /// Fraction of clip spent drawing the crack across the art.
    var crackDrawDuration: CGFloat = 0.08
    /// Clip fraction at which the small fissure begins opening (end of the crack draw).
    var crackOpenStart: CGFloat = 0.08
    /// Clip fraction at which the full split begins (halves pull apart).
    var splitDelay: CGFloat = 0.30

    static let production = Self()

    /// Particle layouts depend only on this fixed config, never on animation
    /// progress, so they are cached instead of rebuilt every frame. This is the
    /// only production config (`BattleSliceArtwork`); a non-default config must
    /// not be introduced without revisiting the cache in `CombatantSliceEffect`.
    static let productionLeftParticles = SliceBorderParticle.make(
        count: max(production.particleCount / 2, 16),
        isPrimary: true
    )
    static let productionRightParticles = SliceBorderParticle.make(
        count: max(production.particleCount / 2, 16),
        salt: 40,
        isPrimary: false
    )
    static let productionCutParticles = SliceCutParticle.make(
        count: max(production.particleCount, 32)
    )
}

/// Progress-driven Slice death renderer (0…1 clip progress).
struct CombatantSliceEffect<Content: View>: View {
    let config: CombatantSliceEffectConfig
    let progress: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            slice(size: geometry.size)
        }
        .allowsHitTesting(false)
        .onAppear {
            CardDissolveTexture.prewarm(
                cutAngleDegrees: CombatantSliceGeometry.angleDegrees
            )
        }
        .task {
            // Bake dissolve masks before the mid-clip transition so the first
            // threshold step never stalls the display link (which froze motion).
            await CardDissolveTexture.prepare(
                cutAngleDegrees: CombatantSliceGeometry.angleDegrees
            )
        }
    }

    private var effectiveProgress: CGFloat {
        min(max(progress * config.speed, 0), 1)
    }

    private func slice(size: CGSize) -> some View {
        let delay = min(max(config.splitDelay, 0), 0.6)
        let p = effectiveProgress
        // Small fissure: the crack line has just drawn across the art, so a
        // short crack gap ramps in quickly and holds so the fissure reads.
        let crackT = min(max((p - config.crackOpenStart) / 0.06, 0), 1)
        let crackGapAmount = size.width * config.crackGap * crackT * config.intensity
        // Full split on top of the fissure — fast, smooth ease-out separation so
        // halves break apart responsively without a linear jerk or view branch swap.
        let rawSplitT = delay >= 1 ? 0 : min(max((p - delay) / (1 - delay), 0), 1)
        let splitT = 1 - pow(1 - rawSplitT, 3)
        let gap = crackGapAmount
            + size.width * max(config.splitGap - config.crackGap, 0) * splitT * config.intensity
        let lift = size.height * 0.08 * splitT * config.intensity
        let twist = 7.0 * Double(splitT * config.intensity)
        // Wipe begins with the full split and spans the rest of the clip so each
        // half dissolves slowly while the pieces drift apart.
        let dissolveStart = delay
        let dissolveLinear = dissolveStart >= 1
            ? 0
            : min(max((p - dissolveStart) / (1 - dissolveStart), 0), 1)
        // Heavy ease-in keeps the wipe gradual across the longer post-split window.
        let dissolveEased = pow(dissolveLinear, 2.6)
        let halfParticles = max(config.particleCount / 2, 16)
        let radians = CombatantSliceGeometry.angleRadians
        let normal = CGVector(dx: cos(radians), dy: -sin(radians))
        let leftParticles = halfParticles == CombatantSliceEffectConfig.productionLeftParticles.count
            ? CombatantSliceEffectConfig.productionLeftParticles
            : SliceBorderParticle.make(count: halfParticles, isPrimary: true)
        let rightParticles = halfParticles == CombatantSliceEffectConfig.productionRightParticles.count
            ? CombatantSliceEffectConfig.productionRightParticles
            : SliceBorderParticle.make(count: halfParticles, salt: 40, isPrimary: false)
        let cutParticles = max(config.particleCount, 32) == CombatantSliceEffectConfig.productionCutParticles.count
            ? CombatantSliceEffectConfig.productionCutParticles
            : SliceCutParticle.make(count: max(config.particleCount, 32))

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
                crackProgress: crackT,
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
        // Snap the crack on quickly, hold until the full split, then fade as halves move.
        let drawDuration = min(max(config.crackDrawDuration, 0.001), max(delay, 0.001))
        let draw = min(max(p / drawDuration, 0), 1)
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
                        thresholdContrast: dissolveConfig.dissolveThresholdContrast,
                        cutAngleDegrees: CombatantSliceGeometry.angleDegrees
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
                CrackSliceMask(isPrimary: isPrimary)
                    .frame(width: size.width, height: size.height)
            )
    }
}

/// Auto-playing enemy Slice death, matching `BattleDissolveArtwork` teardown.
struct BattleSliceArtwork<Content: View>: View {
    let content: Content
    private let config: CombatantSliceEffectConfig

    @State private var startDate = Date()
    @State private var isComplete = false

    init(
        config: CombatantSliceEffectConfig = .production,
        @ViewBuilder content: () -> Content
    ) {
        self.config = config
        self.content = content()
    }

    var body: some View {
        // Once Slice finishes the art is fully gone — tear down the display
        // clock so defeated panes do not tick for the rest of the fight.
        Group {
            if isComplete {
                Color.clear
            } else {
                TimelineView(.animation) { timeline in
                    let progress = min(
                        max(
                            timeline.date.timeIntervalSince(startDate)
                                / TrinketMotion.Battle.combatantSliceDuration,
                            0
                        ),
                        1
                    )
                    CombatantSliceEffect(
                        config: config,
                        progress: CGFloat(progress)
                    ) {
                        content
                    }
                }
                .onAppear {
                    startDate = Date()
                    isComplete = false
                }
                .task(id: startDate) {
                    try? await Task.sleep(for: .seconds(TrinketMotion.Battle.combatantSliceDuration))
                    guard !Task.isCancelled else { return }
                    isComplete = true
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Cut angle from vertical for Slice (negative = lean left).
enum CombatantSliceGeometry {
    static let angleDegrees: CGFloat = -30
    static var angleRadians: CGFloat {
        angleDegrees * .pi / 180
    }
}

/// Half-plane on one side of the jagged Slice crack through the card center.
private struct CrackSliceMask: Shape {
    var isPrimary: Bool

    func path(in rect: CGRect) -> Path {
        let normal = CGVector(
            dx: cos(CombatantSliceGeometry.angleRadians),
            dy: -sin(CombatantSliceGeometry.angleRadians)
        )
        let extent = max(rect.width, rect.height) * 2.2
        let sign: CGFloat = isPrimary ? -1 : 1
        let crack = CombatantSliceCrack.points.map { point in
            CGPoint(x: point.x * rect.width, y: point.y * rect.height)
        }
        guard let first = crack.first, let last = crack.last else {
            return Path()
        }
        let farOffset = CGVector(dx: normal.dx * extent * sign, dy: normal.dy * extent * sign)
        var path = Path()
        path.move(to: first)
        for point in crack.dropFirst() {
            path.addLine(to: point)
        }
        path.addLine(to: CGPoint(x: last.x + farOffset.dx, y: last.y + farOffset.dy))
        path.addLine(to: CGPoint(x: first.x + farOffset.dx, y: first.y + farOffset.dy))
        path.closeSubpath()
        return path
    }
}

private extension CardCastEffectConfiguration {
    /// Half dissolve for Slice — ease is applied by the caller across the full
    /// post-split window; shrink stays 0 so halves keep sliding.
    static let sliceHalfDissolve = CardCastEffectConfiguration(
        dissolveDuration: 1, dissolveShrink: 0, particleDistance: 110, particleDistanceVariation: 50,
        particleDelay: 0.12, particleLifetime: 0.55, particleLifetimeVariation: 0.2, particleCurve: 0.85,
        particleOriginSpread: 1, particleSize: 3.0, particleSizeVariation: 2.6, fadeStart: 0.2,
        particleAgeEasePower: 1.8, particleSizeShrink: 0.4, particleFadeExponent: 1.3, particlePathControl: 0.35
    )
}

/// Progressive grey/white crack line drawn tip-forward along the jagged crack,
/// so the fissure visibly changes angles as it races across the art.
private func drawSliceLine(
    in context: inout GraphicsContext,
    size: CGSize,
    drawProgress: CGFloat,
    intensity: CGFloat
) {
    let lead = min(max(drawProgress, 0), 1)
    let pixels = CombatantSliceCrack.polylinePoints(toFraction: lead, size: size)
    let tip = pixels[pixels.count - 1]
    let stableIntensity = max(intensity, 0.35)

    var streak = Path()
    streak.move(to: pixels[0])
    for point in pixels.dropFirst() {
        streak.addLine(to: point)
    }
    context.stroke(
        streak,
        with: .color(TrinketDesign.Colors.battleSliceCrack.opacity(Double(0.95 * intensity))),
        style: StrokeStyle(
            lineWidth: 2.6 * stableIntensity,
            lineCap: .round,
            lineJoin: .round
        )
    )
    // Bright tip so the crack reads as cracking across, not revealed all at once.
    let tipRadius = 2.2 * stableIntensity
    let tipRect = CGRect(
        x: tip.x - tipRadius,
        y: tip.y - tipRadius,
        width: tipRadius * 2,
        height: tipRadius * 2
    )
    context.fill(
        Path(ellipseIn: tipRect),
        with: .color(TrinketDesign.Colors.battleSliceCrack.opacity(Double(intensity)))
    )
}
