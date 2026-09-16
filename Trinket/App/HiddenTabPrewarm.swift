import SwiftUI
import TrinketDesignSystem

struct HiddenTabPrewarm: View {
    /// Failsafe so one surface that never lays out cannot stall launch.
    private static let layoutTimeout: Duration = .seconds(5)

    private enum Surface: CaseIterable, Hashable {
        case collection, homestead, options
    }

    @State private var laidOutSurfaces: Set<Surface> = []
    var onFirstLayout: () -> Void = {}

    var body: some View {
        // Intentionally mounts root surfaces only: the same NavigationStack
        // shape as the real tabs warms first layout without triggering
        // navigation-bound side effects (e.g. consuming the pending
        // Collection presentation, which only the visible tab performs).
        ZStack {
            NavigationStack {
                CollectionView()
                    .onGeometryChange(for: Bool.self) { geometry in
                        geometry.size.width > 0 && geometry.size.height > 0
                    } action: { hasLayout in
                        acknowledgeLayout(.collection, hasLayout: hasLayout)
                    }
            }
            NavigationStack {
                HomesteadView()
                    .onGeometryChange(for: Bool.self) { geometry in
                        geometry.size.width > 0 && geometry.size.height > 0
                    } action: { hasLayout in
                        acknowledgeLayout(.homestead, hasLayout: hasLayout)
                    }
            }
            NavigationStack {
                OptionsView()
                    .onGeometryChange(for: Bool.self) { geometry in
                        geometry.size.width > 0 && geometry.size.height > 0
                    } action: { hasLayout in
                        acknowledgeLayout(.options, hasLayout: hasLayout)
                    }
            }
        }
        .trinketDecorativeMotion(false)
        .opacity(0.001)
        .scaleEffect(0.01)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: Self.layoutTimeout)
            guard !Task.isCancelled else { return }
            acknowledgeTimeout()
        }
    }

    private func acknowledgeTimeout() {
        guard laidOutSurfaces.count != Surface.allCases.count else { return }
        onFirstLayout()
    }

    private func acknowledgeLayout(_ surface: Surface, hasLayout: Bool) {
        guard hasLayout, laidOutSurfaces.insert(surface).inserted else { return }
        if laidOutSurfaces.count == Surface.allCases.count {
            onFirstLayout()
        }
    }
}
