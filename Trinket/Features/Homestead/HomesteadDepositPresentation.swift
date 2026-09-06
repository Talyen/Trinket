import SwiftUI
import TrinketCore
import TrinketFeatureAdapters
import TrinketFeatureSupport

struct HomesteadDepositEvent: Identifiable {
    let id = UUID()
    let amounts: [ResourceAmount]
    let geometry: HomesteadDepositGeometry
    var gathered = false
    var progress: [HomesteadResource: CGFloat] = [:]
    var landed: Set<HomesteadResource> = []
}

struct HomesteadDepositGeometry: Equatable {
    var sources: [HomesteadResource: CGRect] = [:]
    var destinations: [HomesteadResource: CGRect] = [:]
    var viewport: CGRect = .zero

    func hasSameDestinations(as other: Self) -> Bool {
        viewport == other.viewport && destinations == other.destinations
    }

    func supports(_ amounts: [ResourceAmount]) -> Bool {
        amounts.allSatisfy { amount in
            guard let source = sources[amount.resource],
                  let destination = destinations[amount.resource] else { return false }
            return source.width > 0 && destination.width > 0
                && viewport.contains(source) && viewport.contains(destination)
        }
    }
}

struct HomesteadCollectionArtworkAnchors: PreferenceKey {
    static var defaultValue: [HomesteadResource: Anchor<CGRect>] {
        [:]
    }

    static func reduce(
        value: inout [HomesteadResource: Anchor<CGRect>],
        nextValue: () -> [HomesteadResource: Anchor<CGRect>],
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct HomesteadDepositOverlay: ViewModifier {
    let event: HomesteadDepositEvent?
    let geometryChanged: ([HomesteadResource: CGRect], Bool, CGRect) -> Void

    func body(content: Content) -> some View {
        content
            .backgroundPreferenceValue(HomesteadCollectionArtworkAnchors.self) { sources in
                GeometryReader { proxy in
                    let frames = sources.mapValues { proxy[$0] }
                    Color.clear.onChange(of: frames, initial: true) { _, newValue in
                        geometryChanged(newValue, true, CGRect(origin: .zero, size: proxy.size))
                    }
                }
            }
            .overlayPreferenceValue(HomesteadWalletArtworkAnchors.self) { destinations in
                GeometryReader { proxy in
                    let geometry = HomesteadDepositGeometry(
                        destinations: destinations.mapValues { proxy[$0] },
                        viewport: CGRect(origin: .zero, size: proxy.size),
                    )
                    ZStack(alignment: .topLeading) {
                        Color.clear
                        if let event {
                            ForEach(event.amounts) { amount in
                                if let source = event.geometry.sources[amount.resource],
                                   let destination = event.geometry.destinations[amount.resource] {
                                    HomesteadDepositFlight(
                                        resource: amount.resource,
                                        source: source,
                                        destination: destination,
                                        progress: event.progress[amount.resource, default: 0],
                                        gather: event.gathered ? 1 : 0,
                                    )
                                }
                            }
                        }
                    }
                    .onChange(of: geometry, initial: true) { _, newValue in
                        geometryChanged(newValue.destinations, false, newValue.viewport)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}

struct HomesteadDepositFlight: View, Animatable {
    let resource: HomesteadResource
    let source: CGRect
    let destination: CGRect
    nonisolated var progress: CGFloat
    nonisolated var gather: CGFloat

    nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, gather) }
        set {
            progress = newValue.first
            gather = newValue.second
        }
    }

    var body: some View {
        let start = CGPoint(x: source.midX, y: source.midY - 4 * gather)
        let end = CGPoint(x: destination.midX, y: destination.midY)
        let control = CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - 20)
        let remaining = 1 - progress
        let point = CGPoint(
            x: remaining * remaining * start.x + 2 * remaining * progress * control.x + progress * progress * end.x,
            y: remaining * remaining * start.y + 2 * remaining * progress * control.y + progress * progress * end.y,
        )
        HomesteadResourceArtwork(resource: resource)
            .frame(width: source.width, height: source.height)
            .scaleEffect(1 - 0.06 * gather * remaining)
            .opacity(progress < 0.82 ? 1 : (1 - progress) / 0.18)
            .position(point)
    }
}
