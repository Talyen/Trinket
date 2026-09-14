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
            center: restingCenter,
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
        let configuration = CardDissolveConfiguration()
        let riseProgress = min(max(progress / configuration.dissolveDuration, 0), 1)
        let rise = 1 - pow(1 - riseProgress, 3)

        return CardDissolveEffect(
            progress: progress,
            keywords: request.keywords,
            size: request.size,
            particles: request.particles,
            configuration: configuration,
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
            y: request.center.y - request.size.height * BattleMotion.cardPlayRiseHeightFraction * rise,
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

    public var artworkName: String?
    private let isRenderingEnabled: Bool
    private let onComplete: () -> Void
    private let cardSize = CGSize(width: 168, height: 224)

    @State private var startDate: Date?
    @State private var preparedArtworkName: String?
    @State private var areResourcesPrepared = false

    public init(
        artworkName: String? = "ability_bash",
        isRenderingEnabled: Bool = true,
        onComplete: @escaping () -> Void,
    ) {
        self.artworkName = artworkName
        self.isRenderingEnabled = isRenderingEnabled
        self.onComplete = onComplete
    }

    public var body: some View {
        Group {
            if canRender, let startDate {
                TimelineView(.animation) { timeline in
                    CardDissolveEffect(
                        progress: cardActivationProgress(elapsed: timeline.date.timeIntervalSince(startDate)),
                        keywords: [.physical],
                        size: cardSize,
                        particles: Self.prewarmParticles,
                    ) {
                        BattleAbilityCardFace(artworkName: artworkName)
                    }
                }
            } else {
                Color.clear
            }
        }
        .opacity(0.001)
        .scaleEffect(0.01)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: artworkName) {
            areResourcesPrepared = false
            startDate = nil
            releaseArtwork()
            async let textures: Void = CardDissolveTexture.prepare()
            if let artworkName {
                await PreparedArtworkCache.shared.prepareAndPin(names: [artworkName])
                guard !Task.isCancelled else {
                    PreparedArtworkCache.shared.releasePins(names: [artworkName])
                    return
                }
                preparedArtworkName = artworkName
            }
            await textures
            guard !Task.isCancelled else { return }
            areResourcesPrepared = true
        }
        .task(id: renderKey) {
            guard canRender else {
                startDate = nil
                return
            }
            startDate = .now
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            onComplete()
        }
        .onDisappear {
            areResourcesPrepared = false
            startDate = nil
            releaseArtwork()
        }
    }

    private var canRender: Bool {
        isRenderingEnabled && areResourcesPrepared && preparedArtworkName == artworkName
    }

    private var renderKey: String? {
        canRender ? (artworkName ?? "") : nil
    }

    private func releaseArtwork() {
        if let preparedArtworkName {
            PreparedArtworkCache.shared.releasePins(names: [preparedArtworkName])
            self.preparedArtworkName = nil
        }
    }
}
