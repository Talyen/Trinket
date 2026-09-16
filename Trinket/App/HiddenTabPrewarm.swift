import os
import SwiftUI
import TrinketDesignSystem
import TrinketPersistence

private let hiddenTabPrewarmLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "HiddenTabPrewarm",
)

struct HiddenTabPrewarm: View {
    /// Failsafe so one surface that never lays out cannot stall launch.
    private static let layoutTimeout: Duration = .seconds(5)

    private enum Surface: CaseIterable, Hashable {
        case collection, homestead, options
    }

    @State private var laidOutSurfaces: Set<Surface> = []
    var onFirstLayout: () -> Void = {}

    var body: some View {
        // Intentionally mounts root surfaces only (not the full navigation
        // state of the real tabs): this warms first layout without triggering
        // navigation-bound side effects (e.g. consuming the pending
        // Collection presentation, which only the visible tab performs).
        // First-run players skip prewarm entirely; only mounted after starter
        // selection completes (see PreparedAppRoot.shouldWarmHiddenTabs).
        ZStack {
            NavigationStack {
                CollectionView()
                    .onFirstNonzeroLayout {
                        acknowledgeLayout(.collection)
                    }
            }
            NavigationStack {
                HomesteadView()
                    .onFirstNonzeroLayout {
                        acknowledgeLayout(.homestead)
                    }
            }
            NavigationStack {
                OptionsView()
                    .onFirstNonzeroLayout {
                        acknowledgeLayout(.options)
                    }
            }
        }
        .trinketDecorativeMotion(false)
        .opacity(0.001)
        .scaleEffect(0.01)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            // Cancelled automatically when early success unmounts this view.
            try? await Task.sleep(for: Self.layoutTimeout)
            guard !Task.isCancelled else { return }
            acknowledgeTimeout()
        }
    }

    private func acknowledgeTimeout() {
        guard laidOutSurfaces.count != Surface.allCases.count else { return }
        hiddenTabPrewarmLogger.error(
            "Hidden tab prewarm timed out with \(laidOutSurfaces.count, privacy: .public) of 3 surfaces laid out; releasing launch gate anyway.",
        )
        onFirstLayout()
    }

    private func acknowledgeLayout(_ surface: Surface) {
        guard laidOutSurfaces.insert(surface).inserted else { return }
        if laidOutSurfaces.count == Surface.allCases.count {
            onFirstLayout()
        }
    }
}
