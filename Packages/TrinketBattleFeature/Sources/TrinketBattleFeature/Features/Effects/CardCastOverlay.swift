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
        particles = CardActivationParticle.make(count: particleCount)
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
        CardDissolveEffect(
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

public struct CardCastEffectsPrewarmView: View {
    private static let prewarmParticles = CardActivationParticle.make(
        count: BattleMotion.cardCastParticleCount,
    )

    public var artworkName: String? = "ability_bash"
    let onComplete: () -> Void

    private let cardSize = CGSize(width: 168, height: 224)

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
            CardDissolveEffect(
                progress: progress,
                keywords: [.physical],
                size: cardSize,
                particles: Self.prewarmParticles,
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
