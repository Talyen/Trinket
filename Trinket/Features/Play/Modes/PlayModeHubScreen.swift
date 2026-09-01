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
                columns: TrinketDesign.Layout.hubGridItems(for: horizontalSizeClass),
                spacing: TrinketDesign.Spacing.large,
            ) {
                content()
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .padding(.top, TrinketDesign.Layout.compactContentTopPadding)
            .padding(.bottom, TrinketDesign.Spacing.extraLarge)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground()
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
