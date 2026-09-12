import BattleEngine
import Observation
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

@MainActor
@Observable
final class BattleCastPresentationState {
    private(set) var requests: [CardActivationRequest] = []
    var request: CardActivationRequest? {
        requests.last
    }

    var stuckResetDelayOverride: TimeInterval?

    @ObservationIgnored
    private var pendingStuckResetTasks: [UUID: Task<Void, Never>] = [:]

    func append(_ request: CardActivationRequest) {
        if requests.count == 6, let oldest = requests.first {
            withAnimation(.easeOut(duration: BattleMotion.feedbackHandoffDuration)) {
                remove(id: oldest.id)
            }
        }
        requests.append(request)
        scheduleStuckReset(for: request)
    }

    func remove(id: UUID) {
        requests.removeAll { $0.id == id }
        pendingStuckResetTasks.removeValue(forKey: id)?.cancel()
    }

    func reset() {
        requests.removeAll()
        for task in pendingStuckResetTasks.values {
            task.cancel()
        }
        pendingStuckResetTasks.removeAll()
    }

    func setSuspended(_ suspended: Bool, at date: Date = .now) {
        for index in requests.indices {
            if suspended, requests[index].pausedAt == nil {
                requests[index].pausedAt = date
                pendingStuckResetTasks.removeValue(forKey: requests[index].id)?.cancel()
            } else if !suspended, let pausedAt = requests[index].pausedAt {
                requests[index].startedAt += date.timeIntervalSince(pausedAt)
                requests[index].pausedAt = nil
                scheduleStuckReset(for: requests[index])
            }
        }
    }

    private func scheduleStuckReset(for request: CardActivationRequest) {
        pendingStuckResetTasks.removeValue(forKey: request.id)?.cancel()
        let delay = stuckResetDelayOverride
            ?? max(0, BattleMotion.cardActivationDuration - Date.now.timeIntervalSince(request.startedAt))
            + BattleMotion.cardActivationStuckSlack
        pendingStuckResetTasks[request.id] = Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            self?.remove(id: request.id)
        }
    }
}

struct CardActivationRequest: Equatable, Identifiable {
    let id: UUID
    var startedAt: Date
    var pausedAt: Date?
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

    static func restingRequest(
        for card: BattleCard,
        index: Int,
        cardCount: Int,
        battleSize: CGSize,
        liftFraction: CGFloat = 0,
        startedAt: Date = .now,
    ) -> Self {
        let metrics = BattleHandLayout.metrics(
            containerWidth: battleSize.width,
            cardCount: cardCount,
        )
        let restingCenter = BattleHandLayout.restingCenter(
            index: index,
            metrics: metrics,
            cardCount: cardCount,
            containerFrame: CGRect(origin: .zero, size: battleSize),
        )
        return Self(
            startedAt: startedAt,
            artworkName: card.ability.artReference?.imageName,
            center: CGPoint(
                x: restingCenter.x,
                y: restingCenter.y - metrics.cardHeight * liftFraction,
            ),
            size: CGSize(width: metrics.cardWidth, height: metrics.cardHeight),
            rotation: BattleHandLayout.rotation(index: index, cardCount: cardCount) * .pi / 180,
            verticalTilt: 0,
            scale: 1,
            perspective: BattleMotion.cardPerspective,
            keywords: card.ability.presentationKeywords,
        )
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
        TimelineView(.animation(paused: request == nil || request?.pausedAt != nil)) { timeline in
            let displayedRequest = request ?? Self.idleRequest
            let progress = request.map {
                cardActivationProgress(elapsed: ($0.pausedAt ?? timeline.date).timeIntervalSince($0.startedAt))
            } ?? 0
            cast(displayedRequest, progress: progress)
                .opacity(request == nil ? 0 : 1)
        }
        .task(id: request) {
            guard let request, request.pausedAt == nil else { return }
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
        .position(
            x: request.center.x,
            y: request.center.y - request.size.height * BattleMotion.tapLiftHeightFraction * min(1, progress * 4),
        )
    }
}

struct CardCastPresentationLane: View {
    let presentation: BattleCastPresentationState
    let playback: BattleCardPlaybackState
    let battleSize: CGSize
    let hapticsEnabled: Bool

    var body: some View {
        ZStack {
            ForEach(presentation.requests) { request in
                CardCastEffectsLayer(request: request) { requestID in
                    presentation.remove(id: requestID)
                }
                .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: playback.isSuspended) { _, suspended in
            presentation.setSuspended(suspended)
        }
        .onDisappear {
            presentation.reset()
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
