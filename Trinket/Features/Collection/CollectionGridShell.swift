import SwiftUI
import TrinketAppState
import TrinketDesignSystem
import TrinketFeatureSupport

@MainActor
struct CollectionGridShell<Data: RandomAccessCollection, Content: View, EmptyContent: View>: View where Data.Element: Identifiable {
    let items: Data
    @ViewBuilder let content: (Data.Element) -> Content
    @ViewBuilder let emptyView: () -> EmptyContent

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
