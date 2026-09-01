import SwiftUI
import TrinketDesignSystem

@MainActor
public struct OptionPickerGrid<Item: Identifiable, CardView: View>: View {
    let items: [Item]
    let isSelected: (Item) -> Bool
    let isEligible: (Item) -> Bool
    let onSelect: (Item) -> Void
    let onLongPress: ((Item) -> Void)?
    let accessibilityIdentifier: (Item) -> String
    var zoomNamespace: Namespace.ID?
    let artworkNameProvider: ((Item) -> String?)?
    let viewportPrefetchRows: Int
    let viewportEstimatedColumns: Int
    @ViewBuilder let card: (Item, Bool) -> CardView
    @State private var visibleIDs: Set<Item.ID> = []

    public init(
        items: [Item],
        isSelected: @escaping (Item) -> Bool,
        isEligible: @escaping (Item) -> Bool = { _ in true },
        onSelect: @escaping (Item) -> Void,
        onLongPress: ((Item) -> Void)? = nil,
        accessibilityIdentifier: @escaping (Item) -> String,
        zoomNamespace: Namespace.ID? = nil,
        artworkNameProvider: ((Item) -> String?)? = nil,
        viewportPrefetchRows: Int = ArtworkViewportPrewarm.defaultPrefetchRows,
        viewportEstimatedColumns: Int = ArtworkViewportPrewarm.partyPickerEstimatedColumns,
        @ViewBuilder card: @escaping (Item, Bool) -> CardView,
    ) {
        self.items = items
        self.isSelected = isSelected
        self.isEligible = isEligible
        self.onSelect = onSelect
        self.onLongPress = onLongPress
        self.accessibilityIdentifier = accessibilityIdentifier
        self.zoomNamespace = zoomNamespace
        self.artworkNameProvider = artworkNameProvider
        self.viewportPrefetchRows = viewportPrefetchRows
        self.viewportEstimatedColumns = viewportEstimatedColumns
        self.card = card
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(
                columns: TrinketDesign.Layout.partyPickerGridItems,
                spacing: TrinketDesign.Spacing.large,
            ) {
                ForEach(items) { item in
                    let eligible = isEligible(item)
                    let selected = isSelected(item)

                    InspectableTapButton(
                        action: {
                            guard eligible else { return }
                            onSelect(item)
                        },
                        longPress: inspectAction(for: item, eligible: eligible),
                        isDisabled: !eligible,
                        label: {
                            card(item, selected)
                                .opacity(eligible ? 1.0 : 0.4)
                        },
                    )
                    .trinketSelectionCardButtonStyle()
                    .optionalMatchedTransitionSource(id: item.id, in: zoomNamespace)
                    .accessibilityIdentifier(accessibilityIdentifier(item))
                    .onAppear {
                        guard artworkNameProvider != nil else { return }
                        visibleIDs.insert(item.id)
                    }
                    .onDisappear {
                        guard artworkNameProvider != nil else { return }
                        visibleIDs.remove(item.id)
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .padding(.vertical, TrinketDesign.Spacing.medium)
        }
        .onChange(of: items.map(\.id)) { _, _ in
            guard artworkNameProvider != nil else { return }
            visibleIDs.formIntersection(items.lazy.map(\.id))
        }
        .task(id: visibleIDs) {
            guard let provider = artworkNameProvider else { return }
            await ArtworkViewportPrewarm.prewarm(
                orderedItems: items,
                visibleIDs: visibleIDs,
                currentVisibleIDs: { visibleIDs },
                thumbnailName: provider,
                prefetchRows: viewportPrefetchRows,
                estimatedColumns: viewportEstimatedColumns,
            )
        }
    }

    private func inspectAction(for item: Item, eligible: Bool) -> (() -> Void)? {
        guard eligible, let onLongPress else { return nil }
        return { onLongPress(item) }
    }
}
