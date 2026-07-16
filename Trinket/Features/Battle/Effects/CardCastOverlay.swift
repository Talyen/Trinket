import Observation
import SwiftUI
import TrinketCore
import TrinketDesignSystem

@MainActor
@Observable
final class BattleCastPresentationState {
    private(set) var requests: [CardActivationRequest] = []

    func append(_ request: CardActivationRequest, enforceProductionCap: Bool = true) {
        requests.append(request)
        guard enforceProductionCap else { return }
        let maximum = TrinketMotion.Battle.maxConcurrentCardCasts
        if requests.count > maximum {
            requests.removeFirst(requests.count - maximum)
        }
    }

    func remove(id: UUID) {
        requests.removeAll { $0.id == id }
    }

    func reset() {
        requests.removeAll(keepingCapacity: true)
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

    static func make(count: Int) -> [Self] {
        (0 ..< max(0, count)).map { index in
            let angle = dissolveNoise(column: index, row: 41) * 2 * .pi
            return Self(
                originXNoise: dissolveNoise(column: index, row: 13),
                originYNoise: dissolveNoise(column: index, row: 29),
                vector: CGVector(dx: cos(angle), dy: sin(angle)),
                distanceNoise: dissolveNoise(column: index, row: 53),
                delayNoise: dissolveNoise(column: index, row: 61),
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
    let requests: [CardActivationRequest]
    let onFinished: (UUID) -> Void

    var body: some View {
        Group {
            if !requests.isEmpty {
                ZStack {
                    TimelineView(.animation) { timeline in
                        ZStack {
                            ForEach(requests) { request in
                                cast(request, at: timeline.date)
                            }
                        }
                    }

                    ForEach(requests) { request in
                        Color.clear
                            .frame(width: 0, height: 0)
                            .task(id: request.id) {
                                let elapsed = Date.now.timeIntervalSince(request.startedAt)
                                let remaining = max(0, TrinketMotion.Battle.cardActivationDuration - elapsed)
                                try? await Task.sleep(for: .seconds(remaining))
                                guard !Task.isCancelled else { return }
                                onFinished(request.id)
                            }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .battleFramePacingSignpost(
            BattleFramePacingSignposts.Name.cardCast,
            isActive: !requests.isEmpty
        )
    }

    private func cast(_ request: CardActivationRequest, at date: Date) -> some View {
        let progress = cardActivationProgress(elapsed: date.timeIntervalSince(request.startedAt))
        return BattleDissolveEffect(
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
        CardCastEffectsLayer(requests: presentation.requests) { requestID in
            presentation.remove(id: requestID)
        }
    }
}

enum CardCastParticleShape: String, CaseIterable, Identifiable {
    case circle
    case square
    case diamond
    case spark

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .circle: "Circle"
        case .square: "Square"
        case .diamond: "Diamond"
        case .spark: "Spark"
        }
    }
}

enum CardCastParticleStyle: String, CaseIterable, Identifiable {
    case solid
    case outline
    case softGlow

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .solid: "Solid"
        case .outline: "Outline"
        case .softGlow: "Soft glow"
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
    var particleShape: CardCastParticleShape = .circle
    var particleStyle: CardCastParticleStyle = .solid
    var particleOutlineWidth: CGFloat = 1.0
    var particleGlowScale: CGFloat = 2.2
    var particleGlowOpacity: CGFloat = 0.35
    var particleSparkLength: CGFloat = 2.4
    var particleAgeEasePower: CGFloat = 2.50
    var particleSizeShrink: CGFloat = 0.30
    var particleFadeExponent: CGFloat = 1.35
    var particlePathControl: CGFloat = 0.45
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
            }

            CardActivationParticles(
                progress: progress,
                keywords: keywords,
                cardSize: size,
                particles: particles,
                configuration: configuration
            )
            .frame(width: size.width + 180, height: size.height + 180)
        }
        .frame(width: size.width, height: size.height)
        // Rasterize the face mask and particle canvas once before applying the
        // outer cast transform. Without this boundary SwiftUI composites every
        // child independently, which is substantially more expensive under overlap.
        .compositingGroup()
    }
}

struct BattleDissolveArtwork<Content: View>: View {
    let content: Content

    @State private var startDate = Date()
    @State private var isComplete = false
    private let particles = CardActivationParticle.make(count: 20)

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
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
                            keywords: [.physical],
                            size: geometry.size,
                            particles: particles
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
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Primes the dissolve texture cache and filter/Canvas pipeline once, then tears down.
struct CardCastEffectsPrewarmView: View {
    let onComplete: () -> Void

    private let cardSize = CGSize(width: 168, height: 224)
    private let particles = CardActivationParticle.make(count: 12)

    var body: some View {
        BattleDissolveEffect(
            progress: 0.45,
            keywords: [.physical],
            size: cardSize,
            particles: particles
        ) {
            Rectangle().fill(TrinketDesign.Colors.Overlay.paper)
        }
        // A nonzero opacity ensures the render is not optimized away. Scaling
        // happens after Canvas rasterization, so the representative workload is
        // still prepared while remaining visually imperceptible.
        .opacity(0.001)
        .scaleEffect(0.01)
        .allowsHitTesting(false)
        .task {
            // Warm the noise texture cache before the first real cast.
            CardDissolveTexture.prewarm()
            // Yield so the dissolve filter + Canvas get one commit, then remove.
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(32))
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
