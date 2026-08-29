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
    @State private var visibleIDStrings: Set<String> = []

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
        @ViewBuilder card: @escaping (Item, Bool) -> CardView
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
                columns: TrinketDesign.Metrics.partyPickerGridItems,
                spacing: TrinketDesign.Metrics.largeSpacing
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
                        }
                    )
                    .trinketSelectionCardButtonStyle()
                    .optionalMatchedTransitionSource(id: item.id, in: zoomNamespace)
                    .accessibilityIdentifier(accessibilityIdentifier(item))
                    .onAppear {
                        guard artworkNameProvider != nil else { return }
                        visibleIDStrings.insert(String(describing: item.id))
                    }
                    .onDisappear {
                        guard artworkNameProvider != nil else { return }
                        visibleIDStrings.remove(String(describing: item.id))
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
        }
        .onChange(of: items.map { String(describing: $0.id) }) { _, _ in
            guard artworkNameProvider != nil else { return }
            visibleIDStrings.formIntersection(items.lazy.map { String(describing: $0.id) })
        }
        .task(id: visibleIDStrings) {
            guard let provider = artworkNameProvider else { return }
            let snapshot = visibleIDStrings
            try? await Task.sleep(for: ArtworkViewportPrewarm.viewportDebounceInterval)
            guard !Task.isCancelled, snapshot == visibleIDStrings else { return }
            let names = ArtworkViewportPrewarm.windowNamesByStringID(
                orderedItems: items,
                visibleIDStrings: snapshot,
                thumbnailName: provider,
                prefetchRows: viewportPrefetchRows,
                estimatedColumns: viewportEstimatedColumns
            )
            guard !names.isEmpty else { return }
            await PreparedArtworkCache.shared.prepare(names: names)
        }
    }

    private func inspectAction(for item: Item, eligible: Bool) -> (() -> Void)? {
        guard eligible, let onLongPress else { return nil }
        return { onLongPress(item) }
    }
}
