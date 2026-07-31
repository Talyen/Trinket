import SwiftUI
import TrinketDesignSystem

@MainActor
public struct SlotSummaryGrid<Slot: Identifiable, CardView: View>: View {
    let slots: [Slot]
    let isLocked: (Slot) -> Bool
    let hasItem: (Slot) -> Bool
    let onSelect: ((Slot) -> Void)?
    let onView: ((Slot) -> Void)?
    let accessibilityIdentifier: (Slot) -> String
    let combinesAccessibilityChildren: Bool
    @ViewBuilder let card: (Slot) -> CardView

    public init(
        slots: [Slot],
        isLocked: @escaping (Slot) -> Bool,
        hasItem: @escaping (Slot) -> Bool,
        onSelect: ((Slot) -> Void)?,
        onView: ((Slot) -> Void)?,
        accessibilityIdentifier: @escaping (Slot) -> String,
        combinesAccessibilityChildren: Bool = false,
        @ViewBuilder card: @escaping (Slot) -> CardView
    ) {
        self.slots = slots
        self.isLocked = isLocked
        self.hasItem = hasItem
        self.onSelect = onSelect
        self.onView = onView
        self.accessibilityIdentifier = accessibilityIdentifier
        self.combinesAccessibilityChildren = combinesAccessibilityChildren
        self.card = card
    }

    public var body: some View {
        HStack(alignment: .top, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            ForEach(slots) { slot in
                let locked = isLocked(slot)
                if let onSelect, !locked {
                    Button {
                        onSelect(slot)
                    } label: {
                        card(slot)
                    }
                    .trinketQuietTapButtonStyle()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .trinketAccessibilityCombine(combinesAccessibilityChildren)
                    .accessibilityIdentifier(accessibilityIdentifier(slot))

                } else if let onView, !locked, hasItem(slot) {
                    Button {
                        onView(slot)
                    } label: {
                        card(slot)
                    }
                    .trinketQuietTapButtonStyle()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .trinketAccessibilityCombine(combinesAccessibilityChildren)
                    .accessibilityIdentifier(accessibilityIdentifier(slot))

                } else {
                    card(slot)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .accessibilityIdentifier(accessibilityIdentifier(slot))
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func trinketAccessibilityCombine(_ combine: Bool) -> some View {
        if combine {
            accessibilityElement(children: .combine)
        } else {
            self
        }
    }
}
