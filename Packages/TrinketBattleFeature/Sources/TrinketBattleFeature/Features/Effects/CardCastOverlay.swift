import Observation
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

@MainActor
@Observable
final class BattleCastPresentationState {
    private(set) var request: CardActivationRequest?
    var stuckResetDelayOverride: TimeInterval?

    @ObservationIgnored
    private var pendingStuckResetTask: Task<Void, Never>?

    func append(_ request: CardActivationRequest) {
        self.request = request
        scheduleStuckReset(for: request.id)
    }

    func remove(id: UUID) {
        guard request?.id == id else { return }
        request = nil
        cancelStuckReset()
    }

    func reset() {
        request = nil
        cancelStuckReset()
    }

    private func scheduleStuckReset(for requestID: UUID) {
        cancelStuckReset()
        let delay = stuckResetDelayOverride
            ?? BattleMotion.cardActivationDuration
            + BattleMotion.cardActivationStuckSlack
        pendingStuckResetTask = Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard let self, !Task.isCancelled else { return }
            remove(id: requestID)
        }
    }

    private func cancelStuckReset() {
        pendingStuckResetTask?.cancel()
        pendingStuckResetTask = nil
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
        particleCount: Int = BattleMotion.cardCastParticleCount,
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
    enum Spread: Equatable {
        case radial
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
                        + dissolveNoise(column: index, row: 61) * (1 / CGFloat(waveCount)),
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
                colorNoise: dissolveNoise(column: index, row: 109),
            )
        }
    }
}

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
        keywords: [.physical],
    )

    var body: some View {
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
            let remaining = max(0, BattleMotion.cardActivationDuration - elapsed)
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            onFinished(request.id)
        }
        .onDisappear {
            if let request {
                onFinished(request.id)
            }
        }
        .allowsHitTesting(false)
        .battleFramePacingSignpost(
            BattleFramePacingSignposts.Name.cardCast,
            isActive: request != nil,
        )
    }

    private func cast(_ request: CardActivationRequest, progress: CGFloat) -> some View {
        BattleDissolveEffect(
            progress: progress,
            keywords: request.keywords,
            size: request.size,
            particles: request.particles,
        ) {
            BattleAbilityCardFace(artworkName: request.artworkName)
        }
        .scaleEffect(request.scale)
        .rotationEffect(.radians(request.rotation), anchor: .bottom)
        .rotation3DEffect(
            .degrees(request.verticalTilt),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: request.perspective,
        )
        .position(x: request.center.x, y: request.center.y)
    }
}

struct CardCastPresentationLane: View {
    let presentation: BattleCastPresentationState

    var body: some View {
        CardCastEffectsLayer(request: presentation.request) { requestID in
            presentation.remove(id: requestID)
        }
    }
}

struct CardCastEffectConfiguration {
    var dissolveDuration: CGFloat = 0.35
    var dissolveShrink: CGFloat = 0.06
    var dissolveEdgeDepthWeight: CGFloat = 0.86
    var dissolveNoiseWeight: CGFloat = 0.18
    var dissolveCellSize: CGFloat = 1
    var dissolveThresholdMidpoint: CGFloat = 0.46
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
        particlePathControl: 0.32,
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
        @ViewBuilder content: () -> Content,
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
                                    thresholdContrast: configuration.dissolveThresholdContrast,
                                )
                            }
                    }
                }
                .frame(width: size.width, height: size.height)
                .scaleEffect(1 - dissolveProgress * configuration.dissolveShrink)
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
                    configuration: configuration,
                )
                .frame(width: size.width + travelPad * 2, height: size.height + travelPad * 2)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

private enum BattleDissolveParticles {
    static let standard = CardActivationParticle.make(count: 20)
    static let defeat = CardActivationParticle.make(count: 28, spread: .fireworks)
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
        @ViewBuilder content: () -> Content,
    ) {
        self.celebratesDefeat = celebratesDefeat
        self.onFinished = onFinished
        self.content = content()
        if celebratesDefeat {
            particles = BattleDissolveParticles.defeat
            keywords = [.gold, .holy]
            configuration = .defeatCelebration
        } else {
            particles = BattleDissolveParticles.standard
            keywords = [.physical]
            configuration = CardCastEffectConfiguration()
        }
    }

    public var body: some View {
        Group {
            if isComplete {
                Color.clear
            } else {
                TimelineView(.animation) { timeline in
                    GeometryReader { geometry in
                        let progress = cardActivationProgress(
                            elapsed: timeline.date.timeIntervalSince(startDate),
                        )

                        BattleDissolveEffect(
                            progress: progress,
                            keywords: keywords,
                            size: geometry.size,
                            particles: particles,
                            configuration: configuration,
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
                    try? await Task.sleep(for: .seconds(BattleMotion.cardActivationDuration))
                    guard !Task.isCancelled else { return }
                    isComplete = true
                    onFinished?()
                }
            }
        }
        .allowsHitTesting(false)
    }
}

public struct CardCastEffectsPrewarmView: View {
    private static let prewarmParticles = CardActivationParticle.make(
        count: BattleMotion.cardCastParticleCount,
    )

    public var artworkName: String? = "ability_bash"
    let onComplete: () -> Void

    private let cardSize = CGSize(width: 168, height: 224)
    private var particles: [CardActivationParticle] {
        Self.prewarmParticles
    }

    @State private var startDate = Date()

    public init(
        artworkName: String? = "ability_bash",
        onComplete: @escaping () -> Void,
    ) {
        self.artworkName = artworkName
        self.onComplete = onComplete
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let progress = cardActivationProgress(
                elapsed: timeline.date.timeIntervalSince(startDate),
            )
            BattleDissolveEffect(
                progress: progress,
                keywords: [.physical],
                size: cardSize,
                particles: particles,
            ) {
                BattleAbilityCardFace(artworkName: artworkName)
            }
        }
        .opacity(0.001)
        .scaleEffect(0.01)
        .allowsHitTesting(false)
        .task {
            startDate = Date()
            defer {
                if let artworkName {
                    PreparedArtworkCache.shared.releasePins(names: [artworkName])
                }
            }
            if let artworkName {
                await PreparedArtworkCache.shared.prepareAndPin(names: [artworkName])
            }
            await CardDissolveTexture.prepare()
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
    CGFloat(min(max(elapsed / BattleMotion.cardActivationDuration, 0), 1))
}
