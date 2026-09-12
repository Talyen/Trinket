import BattleEngine
import SwiftUI
import TrinketFeatureSupport

struct AutomaticCardCastView: View {
    let cast: BattleRecordedCardCast
    let battleSize: CGSize
    let onFinished: () -> Void

    private let revealDuration: TimeInterval = 0.48

    var body: some View {
        let metrics = BattleHandLayout.metrics(containerWidth: battleSize.width, cardCount: 3)
        let center = CGPoint(
            x: battleSize.width * (cast.card.owner == .hero ? 0.38 : 0.62),
            y: max(
                metrics.cardHeight / 2,
                battleSize.height - BattleCardGridLayout.handReservedHeight
                    - BattleHandLayout.bottomRise - metrics.cardHeight / 2,
            ),
        )
        TimelineView(.animation(paused: cast.pausedAt != nil)) { timeline in
            let elapsed = (cast.pausedAt ?? timeline.date).timeIntervalSince(cast.startedAt)
            let arrival = min(1, max(0, elapsed / BattleMotion.cardDealDuration))
            let eased = 1 - pow(1 - arrival, 3)
            let direction: CGFloat = cast.card.owner == .hero ? -1 : 1
            let progress = cardActivationProgress(elapsed: max(0, elapsed - revealDuration))
            CardDissolveEffect(
                progress: progress,
                keywords: cast.card.ability.presentationKeywords,
                size: CGSize(width: metrics.cardWidth, height: metrics.cardHeight),
                particles: [],
            ) {
                BattleAbilityCardFace(artworkName: cast.card.ability.artReference?.imageName)
            }
            .rotationEffect(.degrees(direction * 18 * (1 - eased)))
            .position(
                x: center.x + direction * battleSize.width * (1 - eased),
                y: center.y + metrics.cardHeight * 0.3 * (1 - eased),
            )
            .opacity(elapsed < 0 ? 0 : 1)
        }
        .task(id: cast) {
            guard cast.pausedAt == nil else { return }
            let remaining = max(
                0,
                revealDuration + BattleMotion.cardActivationDuration
                    - Date.now.timeIntervalSince(cast.startedAt),
            )
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            onFinished()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
