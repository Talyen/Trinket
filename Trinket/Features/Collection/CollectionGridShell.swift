import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketDesignSystem
import TrinketFeatureSupport

/// Shared scroll container and grid layout shell for Collection browse screens.
@MainActor
struct CollectionGridShell<Data: RandomAccessCollection, Content: View, EmptyView: View>: View where Data.Element: Identifiable {
    let items: Data
    @ViewBuilder let content: (Data.Element) -> Content
    @ViewBuilder let emptyView: () -> EmptyView

    private let columns = TrinketDesign.Metrics.collectionGridItems

    var body: some View {
        ScrollView {
            if items.isEmpty {
                emptyView()
                    .padding(TrinketDesign.Metrics.contentMargin)
            } else {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionSpacing) {
                    LazyVGrid(columns: columns, spacing: TrinketDesign.Metrics.largeSpacing) {
                        ForEach(items) { item in
                            content(item)
                        }
                    }
                }
                .padding(TrinketDesign.Metrics.contentMargin)
            }
        }
        .trinketScreenBackground()
    }
}
