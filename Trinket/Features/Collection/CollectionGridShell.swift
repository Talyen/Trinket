import SwiftUI
import TrinketAppState
import TrinketDesignSystem
import TrinketFeatureSupport

@MainActor
struct CollectionGridShell<Data: RandomAccessCollection, Content: View, EmptyContent: View>: View where Data.Element: Identifiable {
    let items: Data
    @ViewBuilder let content: (Data.Element) -> Content
    @ViewBuilder let emptyView: () -> EmptyContent

    private let columns = TrinketDesign.Layout.collectionGridItems

    var body: some View {
        ScrollView {
            if items.isEmpty {
                emptyView()
                    .padding(TrinketDesign.Layout.contentMargin)
            } else {
                VStack(alignment: .leading, spacing: TrinketDesign.Layout.sectionSpacing) {
                    LazyVGrid(columns: columns, spacing: TrinketDesign.Spacing.large) {
                        ForEach(items) { item in
                            content(item)
                        }
                    }
                }
                .padding(TrinketDesign.Layout.contentMargin)
            }
        }
        .trinketScreenBackground()
    }
}
