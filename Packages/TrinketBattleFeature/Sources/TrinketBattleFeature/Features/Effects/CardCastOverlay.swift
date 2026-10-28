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

    func blocksAutoBattle(at date: Date) -> Bool {
        requests.contains { request in
            (request.pausedAt ?? date).timeIntervalSince(request.startedAt) < BattleMotion.autoBattleCardInterval
        }
    }

    var stuckResetDelayOverride: TimeInterval?

    @ObservationIgnored
    private var pendingStuckResetTasks: [UUID: Task<Void, Never>] = [:]

    @ObservationIgnored
    private weak var playback: BattleCardPlaybackState?

    func append(_ request: CardActivationRequest, playback: BattleCardPlaybackState? = nil) {
        if let playback {
            self.playback = playback
        }
        while requests.count >= 6, let oldest = requests.first {
            withAnimation(.easeOut(duration: BattleMotion.feedbackHandoffDuration)) {
                remove(id: oldest.id)
            }
        }
        requests.append(request)
        scheduleStuckReset(for: request)
    }

    func remove(id: UUID) {
        playback?.remove(id: id)
        requests.removeAll { $0.id == id }
        pendingStuckResetTasks.removeValue(forKey: id)?.cancel()
    }

    func hideStaleGeometry() {
        for index in requests.indices {
            requests[index].isVisible = false
        }
    }

    func reset() {
        for request in requests {
            playback?.remove(id: request.id)
        }
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
        let endAt = request.completionDate(scheduledCast: playback?.handDeparture(id: request.id))
        let delay = stuckResetDelayOverride
            ?? max(0, endAt.timeIntervalSinceNow)
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
    var isVisible = true
    let artworkName: String?
    let center: CGPoint
    let size: CGSize
    let rotation: CGFloat
    let verticalTilt: CGFloat
    let scale: CGFloat
    let perspective: CGFloat
    let keywords: [Keyword]
    let particles: [CardActivationParticle]

    func completionDate(scheduledCast: BattleRecordedCardCast?) -> Date {
        guard let scheduledCast else {
            return startedAt.addingTimeInterval(BattleMotion.cardActivationDuration)
        }
        // A shortened dissolve must not release autoplay's cadence early.
        return max(scheduledCast.departureEndAt, startedAt.addingTimeInterval(BattleMotion.autoBattleCardInterval))
    }

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
        particles = CardActivationParticle.castParticles
    }

    static func restingRequest(
        for card: BattleCard,
        index: Int,
        cardCount: Int,
        handFrame: CGRect,
        startedAt: Date = .now,
    ) -> Self {
        let metrics = BattleHandLayout.metrics(
            containerWidth: handFrame.width,
            cardCount: cardCount,
            handHeight: handFrame.height,
        )
        let restingCenter = BattleHandLayout.restingCenter(
            index: index,
            metrics: metrics,
            cardCount: cardCount,
            handFrame: handFrame,
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let request: CardActivationRequest
    let scheduledCast: BattleRecordedCardCast?
    let onFinished: (UUID) -> Void

    var body: some View {
        TimelineView(.animation(paused: request.pausedAt != nil)) { timeline in
            let date = request.pausedAt ?? timeline.date
            let progress = scheduledCast?.departureProgress(at: date)
                ?? cardActivationProgress(elapsed: date.timeIntervalSince(request.startedAt))
            cast(request, progress: progress)
                .opacity(request.isVisible ? 1 : 0)
        }
        .task(id: completionDate) {
            guard let completionDate else { return }
            let remaining = max(0, completionDate.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            onFinished(request.id)
        }
        .onDisappear {
            onFinished(request.id)
        }
        .allowsHitTesting(false)
        .battleFramePacingSignpost(
            BattleFramePacingSignposts.Name.cardCast,
            isActive: true,
        )
    }

    private var completionDate: Date? {
        guard request.pausedAt == nil, scheduledCast?.pausedAt == nil else { return nil }
        return request.completionDate(scheduledCast: scheduledCast)
    }

    private func cast(_ request: CardActivationRequest, progress: CGFloat) -> some View {
        let configuration = CardDissolveConfiguration()
        let riseProgress = min(max(progress / configuration.dissolveDuration, 0), 1)
        let rise = reduceMotion ? 0 : BattleMotion.easeOutCubic(Double(riseProgress))

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

    var body: some View {
        ZStack {
            ForEach(presentation.requests) { request in
                CardCastEffectsLayer(request: request, scheduledCast: playback.handDeparture(id: request.id)) { requestID in
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
    public var artworkName: String?
    private let isRenderingEnabled: Bool
    private let onComplete: () -> Void
    private let cardSize = CGSize(width: 168, height: 224)

    @State private var startDate: Date?
    @State private var preparedArtworkName: String?
    @State private var artworkPins = PreparedArtworkPinSet()
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
                        particles: CardActivationParticle.castParticles,
                    ) {
                        BattleAbilityCardFace(artworkName: artworkName)
                    }
                    .overlay {
                        CombatantStatusEffectOverlay(
                            kind: .swirlingStars,
                            progress: 0.5,
                        )
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
                guard await artworkPins.prepare(names: [artworkName]) != nil else { return }
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
        artworkPins.release()
        preparedArtworkName = nil
    }
}
