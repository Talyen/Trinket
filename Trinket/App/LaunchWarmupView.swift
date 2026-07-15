import SwiftUI
import TrinketDesignSystem

struct LaunchWarmupView: View {
    let progress: Double

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
    }
}
