import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct BoonSelectionBurstState: Equatable {
    let keywords: [Keyword]
    let focalPoint: UnitPoint
    let id: UUID

    init(keywords: [Keyword], focalPoint: UnitPoint) {
        self.keywords = keywords
        self.focalPoint = focalPoint
        id = UUID()
    }
}

struct BoonSelectionBurstView: View {
    let state: BoonSelectionBurstState
    @State private var startDate = Date()
    private let duration: TimeInterval = 0.65
    private let particles: [CardActivationParticle] = CardActivationParticle.make(count: 20)
    private let configuration = CardDissolveConfiguration(
        particleDistance: 140,
        particleDistanceVariation: 18,
        particleDelay: 0.02,
        particleLifetime: 0.48,
        particleLifetimeVariation: 0.14,
        particleCurve: 0.55,
        particleOriginSpread: 0.18,
        particleSize: 3.2,
        particleSizeVariation: 2.4,
        fadeStart: 0.22,
        particleAgeEasePower: 2.2,
        particleSizeShrink: 0.42,
        particleFadeExponent: 1.45,
        particlePathControl: 0.42,
    )

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let progress = min(max(elapsed / duration, 0), 1)
            let easedOpacity = burstOpacity(progress: progress)

            GeometryReader { geometry in
                ZStack {
                    KeywordPlasmaBackground(
                        sources: [
                            KeywordPlasmaBackground.Source(
                                keywords: state.keywords,
                                focalPoint: state.focalPoint,
                            ),
                        ],
                        isMotionActive: true,
                    )
                    .opacity(easedOpacity * 0.95)

                    CardActivationParticles(
                        progress: progress,
                        keywords: state.keywords,
                        cardSize: burstCardSize(in: geometry.size),
                        particles: particles,
                        configuration: configuration,
                    )
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                    )
                    .opacity(easedOpacity)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            startDate = Date()
        }
        .id(state.id)
    }

    private func burstOpacity(progress: CGFloat) -> Double {
        if progress >= 1 {
            return 0
        }
        if progress < 0.08 {
            return Double(progress / 0.08)
        }
        let fadeProgress = (progress - 0.08) / 0.92
        return Double(pow(1 - fadeProgress, 1.35))
    }

    private func burstCardSize(in containerSize: CGSize) -> CGSize {
        let width = min(containerSize.width * 0.78, 320)
        let height = min(containerSize.height * 0.22, 110)
        return CGSize(width: width, height: height)
    }
}
