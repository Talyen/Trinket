import Observation
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

@MainActor
@Observable
final class BattleCastPresentationState {
    private(set) var request: CardActivationRequest?

    func append(_ request: CardActivationRequest) {
        self.request = request
    }

    func remove(id: UUID) {
        guard request?.id == id else { return }
        request = nil
    }

    func reset() {
        request = nil
    }
}

struct CardActivationRequest: Equatable, Identifiable {
    let id: UUID
    let startedAt: Date
    let artworkName: String?
    let center: CGPoint
    let size: CGSize
    let rotation: CGFloat
    let verticalTilt: CGFloat
    let scale: CGFloat
    /// Matches the hand card's 3D perspective so cast handoff does not visually jump.
    let perspective: CGFloat
    let keywords: [Keyword]
    let particleCount: Int
    let particles: [CardActivationParticle]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        artworkName: String?,
        center: CGPoint,
        size: CGSize,
        rotation: CGFloat,
        verticalTilt: CGFloat,
        scale: CGFloat,
        perspective: CGFloat = 0.35,
        keywords: [Keyword],
        particleCount: Int = TrinketMotion.Battle.cardCastParticleCount
    ) {
        self.id = id
        self.startedAt = startedAt
        self.artworkName = artworkName
        self.center = center
        self.size = size
        self.rotation = rotation
        self.verticalTilt = verticalTilt
        self.scale = scale
        self.perspective = perspective
        let uniqueKeywords = keywords.reduce(into: [Keyword]()) { result, keyword in
            guard !result.contains(keyword) else { return }
            result.append(keyword)
        }
        self.keywords = uniqueKeywords.isEmpty ? [.physical] : uniqueKeywords
        self.particleCount = particleCount
        particles = CardActivationParticle.make(count: particleCount)
    }
}

struct CardActivationParticle: Equatable {
    /// Radial omnidirectional burst vs upward-biased fireworks with staggered waves.
    enum Spread: Equatable {
        case radial
        /// Upper hemisphere in SwiftUI space (negative Y is up), three delay waves.
        case fireworks
    }

    let originXNoise: CGFloat
    let originYNoise: CGFloat
    let vector: CGVector
    let distanceNoise: CGFloat
    let delayNoise: CGFloat
    let lifetimeNoise: CGFloat
    let curveNoise: CGFloat
    let sizeNoise: CGFloat
    let fadeNoise: CGFloat
    let colorNoise: CGFloat

    static func make(count: Int, spread: Spread = .radial) -> [Self] {
        let waveCount = 3
        return (0 ..< max(0, count)).map { index in
            let angleNoise = dissolveNoise(column: index, row: 41)
            let angle: CGFloat = switch spread {
            case .radial:
                angleNoise * 2 * .pi
            case .fireworks:
                -.pi + angleNoise * .pi
            }
            let delayNoise: CGFloat = switch spread {
            case .radial:
                dissolveNoise(column: index, row: 61)
            case .fireworks:
                min(
                    1,
                    CGFloat(index % waveCount) / CGFloat(waveCount)
                        + dissolveNoise(column: index, row: 61) * (1 / CGFloat(waveCount))
                )
            }
            return Self(
                originXNoise: dissolveNoise(column: index, row: 13),
                originYNoise: dissolveNoise(column: index, row: 29),
                vector: CGVector(dx: cos(angle), dy: sin(angle)),
                distanceNoise: dissolveNoise(column: index, row: 53),
                delayNoise: delayNoise,
                lifetimeNoise: dissolveNoise(column: index, row: 67),
                curveNoise: dissolveNoise(column: index, row: 83),
                sizeNoise: dissolveNoise(column: index, row: 79),
                fadeNoise: dissolveNoise(column: index, row: 101),
                colorNoise: dissolveNoise(column: index, row: 109)
            )
        }
    }
}

/// All active casts share one display-linked clock. Per-request cleanup remains
/// independently cancellable when a cast disappears early.
struct CardCastEffectsLayer: View {
    let request: CardActivationRequest?
    let onFinished: (UUID) -> Void

    private static let idleRequest = CardActivationRequest(
        artworkName: nil,
        center: .zero,
        size: .zero,
        rotation: 0,
        verticalTilt: 0,
        scale: 1,
        keywords: [.physical]
    )

    var body: some View {
        // The complete SwiftUI effect tree stays mounted while idle. A play only
        // replaces immutable request data and wakes the shared animation clock.
        TimelineView(.animation(paused: request == nil)) { timeline in
            let displayedRequest = request ?? Self.idleRequest
            let progress = request.map {
                cardActivationProgress(elapsed: timeline.date.timeIntervalSince($0.startedAt))
            } ?? 0
            cast(displayedRequest, progress: progress)
                .opacity(request == nil ? 0 : 1)
        }
        .task(id: request?.id) {
            guard let request else { return }
            let elapsed = Date.now.timeIntervalSince(request.startedAt)
            let remaining = max(0, TrinketMotion.Battle.cardActivationDuration - elapsed)
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            onFinished(request.id)
        }
        .allowsHitTesting(false)
        .battleFramePacingSignpost(
            BattleFramePacingSignposts.Name.cardCast,
            isActive: request != nil
        )
    }

    private func cast(_ request: CardActivationRequest, progress: CGFloat) -> some View {
        BattleDissolveEffect(
            progress: progress,
            keywords: request.keywords,
            size: request.size,
            particles: request.particles
        ) {
            BattleAbilityCardFace(artworkName: request.artworkName)
        }
        // Match BattleAbilityCardView handoff order: scale → rotate → position.
        .scaleEffect(request.scale)
        .rotationEffect(.radians(request.rotation), anchor: .bottom)
        .rotation3DEffect(
            .degrees(request.verticalTilt),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: request.perspective
        )
        .position(x: request.center.x, y: request.center.y)
    }
}

/// Observation boundary for the cast request collection. Inserts and expirations
/// invalidate only this overlay rather than the battlefield, hand, and toolbar.
struct CardCastPresentationLane: View {
    let presentation: BattleCastPresentationState

    var body: some View {
        CardCastEffectsLayer(request: presentation.request) { requestID in
            presentation.remove(id: requestID)
        }
    }
}

struct CardCastEffectConfiguration {
    /// Fraction of overall cast progress spent dissolving the card face.
    var dissolveDuration: CGFloat = 0.35
    /// How much the card shrinks as dissolve completes.
    var dissolveShrink: CGFloat = 0.06
    /// Outside-in bias weight for the dissolve noise field.
    var dissolveEdgeDepthWeight: CGFloat = 0.86
    /// Random noise weight mixed into the dissolve field.
    var dissolveNoiseWeight: CGFloat = 0.18
    /// Base grid cell size (px) for the dissolve noise field.
    var dissolveCellSize: CGFloat = 1
    /// Brightness midpoint used by the threshold mask (`brightness(midpoint - progress)`).
    /// Kept slightly below 0.5 so progress == 1 clears full-white center pixels past the contrast pivot.
    var dissolveThresholdMidpoint: CGFloat = 0.46
    /// Contrast used to harden the threshold mask into a hard cut.
    var dissolveThresholdContrast: CGFloat = 100

    var particleDistance: CGFloat = 150
    var particleDistanceVariation: CGFloat = 0
    var particleDelay: CGFloat = 0.10
    var particleLifetime: CGFloat = 0.55
    var particleLifetimeVariation: CGFloat = 0.15
    var particleCurve: CGFloat = 1.00
    var particleOriginSpread: CGFloat = 0.50
    var particleSize: CGFloat = 2.5
    var particleSizeVariation: CGFloat = 2.0
    var fadeStart: CGFloat = 0.20
    var fadeStartVariation: CGFloat = 0
    var particleAgeEasePower: CGFloat = 2.50
    var particleSizeShrink: CGFloat = 0.30
    var particleFadeExponent: CGFloat = 1.35
    var particlePathControl: CGFloat = 0.45

    /// Subtle gold fireworks over the dissolving enemy portrait (same 1s window).
    static let defeatCelebration = Self(
        particleDistance: 120,
        particleDistanceVariation: 55,
        particleDelay: 0.42,
        particleLifetime: 0.40,
        particleLifetimeVariation: 0.16,
        particleCurve: 1.40,
        particleOriginSpread: 0.32,
        particleSize: 3.0,
        particleSizeVariation: 2.8,
        fadeStart: 0.40,
        particleAgeEasePower: 2.10,
        particleSizeShrink: 0.50,
        particleFadeExponent: 1.55,
        particlePathControl: 0.32
    )
}

struct BattleDissolveEffect<Content: View>: View {
    let progress: CGFloat
    let keywords: [Keyword]
    let size: CGSize
    let particles: [CardActivationParticle]
    let content: Content
    var configuration = CardCastEffectConfiguration()

    init(
        progress: CGFloat,
        keywords: [Keyword],
        size: CGSize,
        particles: [CardActivationParticle],
        configuration: CardCastEffectConfiguration = CardCastEffectConfiguration(),
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress
        self.keywords = keywords
        self.size = size
        self.particles = particles
        self.configuration = configuration
        self.content = content()
    }

    var body: some View {
        let dissolveProgress = min(progress / max(configuration.dissolveDuration, 0.01), 1)
        let cellSize = Int(configuration.dissolveCellSize.rounded())

        ZStack {
            // After dissolve completes the face is fully gone — skip the filter
            // mask chain for the remaining particle travel window.
            if dissolveProgress < 1 {
                Group {
                    // Progress 0 must not apply the threshold mask: step 0 still
                    // clears edge cells, which would flash a partial wipe on mount.
                    if dissolveProgress <= 0 {
                        content
                            .frame(width: size.width, height: size.height)
                    } else {
                        content
                            .frame(width: size.width, height: size.height)
                            .mask {
                                CardDissolveThresholdMask(
                                    progress: dissolveProgress,
                                    edgeDepthWeight: configuration.dissolveEdgeDepthWeight,
                                    noiseWeight: configuration.dissolveNoiseWeight,
                                    cellSize: cellSize,
                                    thresholdMidpoint: configuration.dissolveThresholdMidpoint,
                                    thresholdContrast: configuration.dissolveThresholdContrast
                                )
                            }
                    }
                }
                .frame(width: size.width, height: size.height)
                .scaleEffect(1 - dissolveProgress * configuration.dissolveShrink)
                // Flatten the masked face only. Wrapping particles here forced a
                // full offscreen re-raster of the card on every Canvas tick.
                .compositingGroup()
            }

            if !particles.isEmpty {
                let travelPad = configuration.particleDistance
                    + configuration.particleDistanceVariation
                    + 40
                CardActivationParticles(
                    progress: progress,
                    keywords: keywords,
                    cardSize: size,
                    particles: particles,
                    configuration: configuration
                )
                .frame(width: size.width + travelPad * 2, height: size.height + travelPad * 2)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

public struct BattleDissolveArtwork<Content: View>: View {
    let celebratesDefeat: Bool
    let onFinished: (() -> Void)?
    let content: Content

    @State private var startDate = Date()
    @State private var isComplete = false
    private let particles: [CardActivationParticle]
    private let keywords: [Keyword]
    private let configuration: CardCastEffectConfiguration

    public init(
        celebratesDefeat: Bool = false,
        onFinished: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.celebratesDefeat = celebratesDefeat
        self.onFinished = onFinished
        self.content = content()
        if celebratesDefeat {
            particles = CardActivationParticle.make(count: 28, spread: .fireworks)
            keywords = [.gold, .holy]
            configuration = .defeatCelebration
        } else {
            particles = CardActivationParticle.make(count: 20)
            keywords = [.physical]
            configuration = CardCastEffectConfiguration()
        }
    }

    public var body: some View {
        // Once dissolve finishes the art is fully gone — tear down the display
        // clock so defeated panes do not tick for the rest of the fight.
        Group {
            if isComplete {
                Color.clear
            } else {
                TimelineView(.animation) { timeline in
                    GeometryReader { geometry in
                        let progress = cardActivationProgress(
                            elapsed: timeline.date.timeIntervalSince(startDate)
                        )

                        BattleDissolveEffect(
                            progress: progress,
                            keywords: keywords,
                            size: geometry.size,
                            particles: particles,
                            configuration: configuration
                        ) {
                            content
                        }
                    }
                }
                .onAppear {
                    startDate = Date()
                    isComplete = false
                }
                .task(id: startDate) {
                    try? await Task.sleep(for: .seconds(TrinketMotion.Battle.cardActivationDuration))
                    guard !Task.isCancelled else { return }
                    isComplete = true
                    onFinished?()
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Primes the dissolve texture cache and the live TimelineView / Canvas cast path
/// once, then tears down. Uses a real ability card face so production first-cast
/// does not pay card-surface + artwork + mask + particles together cold.
public struct CardCastEffectsPrewarmView: View {
    public var artworkName: String? = "ability_bash"
    let onComplete: () -> Void

    private let cardSize = CGSize(width: 168, height: 224)
    private let particles = CardActivationParticle.make(
        count: TrinketMotion.Battle.cardCastParticleCount
    )
    @State private var startDate = Date()

    public init(
        artworkName: String? = "ability_bash",
        onComplete: @escaping () -> Void
    ) {
        self.artworkName = artworkName
        self.onComplete = onComplete
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let progress = cardActivationProgress(
                elapsed: timeline.date.timeIntervalSince(startDate)
            )
            BattleDissolveEffect(
                progress: progress,
                keywords: [.physical],
                size: cardSize,
                particles: particles
            ) {
                BattleAbilityCardFace(artworkName: artworkName)
            }
        }
        // A nonzero opacity ensures the render is not optimized away. Scaling
        // happens after Canvas rasterization, so the representative workload is
        // still prepared while remaining visually imperceptible.
        .opacity(0.001)
        .scaleEffect(0.01)
        .allowsHitTesting(false)
        .task {
            startDate = Date()
            if let artworkName {
                await PreparedArtworkCache.shared.prepareAndPin(names: [artworkName])
            }
            await CardDissolveTexture.prepare()
            // Cover mask onset (dissolveDuration fraction) plus a few particle ticks.
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}

private func dissolveNoise(column: Int, row: Int) -> CGFloat {
    CombatFeedbackLayout.unitNoise(seed: column &* 12989 &+ row &* 78233)
}

private func cardActivationProgress(elapsed: TimeInterval) -> CGFloat {
    CGFloat(min(max(elapsed / TrinketMotion.Battle.cardActivationDuration, 0), 1))
}
