import SwiftUI
import TrinketAppState
import TrinketDesignSystem
import TrinketFeatureSupport

struct PlayModeHubScreen<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let accessibilityIdentifier: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: TrinketDesign.Metrics.hubGridItems(for: horizontalSizeClass),
                spacing: TrinketDesign.Metrics.largeSpacing,
            ) {
                content()
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.top, TrinketDesign.Metrics.compactContentTopPadding)
            .padding(.bottom, TrinketDesign.Metrics.extraLargeSpacing)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground()
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
