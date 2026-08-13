import SwiftUI
import TrinketDesignSystem

@MainActor
public struct OptionPickerGrid<Item: Identifiable, CardView: View>: View {
    let items: [Item]
    let isSelected: (Item) -> Bool
    let isEligible: (Item) -> Bool
    let onSelect: (Item) -> Void
    let accessibilityIdentifier: (Item) -> String
    let accessibilityValue: ((Item) -> String)?
    var zoomNamespace: Namespace.ID?
    @ViewBuilder let card: (Item, Bool) -> CardView

    public init(
        items: [Item],
        isSelected: @escaping (Item) -> Bool,
        isEligible: @escaping (Item) -> Bool = { _ in true },
        onSelect: @escaping (Item) -> Void,
        accessibilityIdentifier: @escaping (Item) -> String,
        accessibilityValue: ((Item) -> String)? = nil,
        zoomNamespace: Namespace.ID? = nil,
        @ViewBuilder card: @escaping (Item, Bool) -> CardView
    ) {
        self.items = items
        self.isSelected = isSelected
        self.isEligible = isEligible
        self.onSelect = onSelect
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityValue = accessibilityValue
        self.zoomNamespace = zoomNamespace
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

                    Button {
                        guard eligible else { return }
                        onSelect(item)
                    } label: {
                        card(item, selected)
                            .opacity(eligible ? 1.0 : 0.4)
                    }
                    .trinketSelectionCardButtonStyle()
                    .disabled(!eligible)
                    .optionalMatchedTransitionSource(id: item.id, in: zoomNamespace)
                    .accessibilityIdentifier(accessibilityIdentifier(item))
                    .trinketAccessibilityValue(accessibilityValue?(item))
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
        }
    }
}

private extension View {
    @ViewBuilder
    func trinketAccessibilityValue(_ value: String?) -> some View {
        if let value {
            accessibilityValue(value)
        } else {
            self
        }
    }
}
