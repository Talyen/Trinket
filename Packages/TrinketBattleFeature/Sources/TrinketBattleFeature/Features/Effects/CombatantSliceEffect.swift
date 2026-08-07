import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

/// Tunables for the enemy Slice death effect (production recipe + lab scrubber).
struct CombatantSliceEffectConfig: Equatable {
    var intensity: CGFloat = 0.5
    var particleCount: Int = 48
    var tintStrength: CGFloat = 0.85
    var speed: CGFloat = 1
    /// Separation between halves as a fraction of card width.
    var splitGap: CGFloat = 0.22
    /// Hold before halves begin to separate (0…1 of the clip).
    var splitDelay: CGFloat = 0.2
    /// Fraction of clip spent drawing the cut stroke — kept short for a snap cut.
    var cutDrawDuration: CGFloat = 0.04

    /// Finalized production recipe from CombatantCardEffectLab.
    static let production = Self()
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
        let rawSplitT = delay >= 1 ? 0 : min(max((p - delay) / (1 - delay), 0), 1)
        // Fast, smooth ease-out separation after cut line finishes so halves break apart
        // responsively without a linear jerk or sudden view branch swap.
        let splitT = 1 - pow(1 - rawSplitT, 3)
        let gap = size.width * config.splitGap * splitT * config.intensity
        let lift = size.height * 0.08 * splitT * config.intensity
        let twist = 7.0 * Double(splitT * config.intensity)
        // Wipe begins with the split and spans the rest of the clip so each half
        // dissolves slowly while the pieces drift apart.
        let dissolveStart = delay
        let dissolveLinear = dissolveStart >= 1
            ? 0
            : min(max((p - dissolveStart) / (1 - dissolveStart), 0), 1)
        // Heavy ease-in keeps the wipe gradual across the longer post-split window.
        let dissolveEased = pow(dissolveLinear, 2.6)
        let halfParticles = max(config.particleCount / 2, 16)
        let radians = CombatantSliceGeometry.angleRadians
        let normal = CGVector(dx: cos(radians), dy: -sin(radians))
        let leftParticles = SliceBorderParticle.make(
            count: halfParticles,
            isPrimary: true
        )
        let rightParticles = SliceBorderParticle.make(
            count: halfParticles,
            salt: 40,
            isPrimary: false
        )
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
        // Snap the stroke on quickly, hold until separation, then fade as halves move.
        let drawDuration = min(max(config.cutDrawDuration, 0.001), max(delay, 0.001))
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
                DiagonalSliceMask(
                    isPrimary: isPrimary,
                    angleDegrees: CombatantSliceGeometry.angleDegrees
                )
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
    /// Half dissolve for Slice — ease is applied by the caller across the full
    /// post-split window; shrink stays 0 so halves keep sliding.
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
    // Linear tip advance — the draw window is already a near-instant snap.
    let lead = min(max(drawProgress, 0), 1)

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
