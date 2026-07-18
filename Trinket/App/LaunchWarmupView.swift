import SwiftUI
import TrinketDesignSystem

struct LaunchWarmupView: View {
    /// Cosmetic fill duration — matches the minimum launch display hold.
    private static let fillDuration: TimeInterval = 1.0

    @State private var progress: Double = 0

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
            Text("TRINKET")
                .trinketTypography(.screenDisplay)
                .foregroundStyle(TrinketDesign.Colors.accent)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(TrinketDesign.Colors.accent)
                .frame(maxWidth: 240)

            Text("Preparing your adventure…")
                .trinketTypography(.secondaryBody)
                .foregroundStyle(.secondary)
        }
        .padding(TrinketDesign.Metrics.contentMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trinketScreenBackground()
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("Launch Warmup")
        .task {
            // Defer past the first committed frame so the fill isn't already
            // finished when the system launch screen hands off to this view.
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: Self.fillDuration)) {
                progress = 1
            }
        }
    }
}
