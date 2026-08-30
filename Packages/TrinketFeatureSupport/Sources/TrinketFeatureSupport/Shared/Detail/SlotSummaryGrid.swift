import SwiftUI
import TrinketDesignSystem

@MainActor
public struct SlotSummaryGrid<Slot: Identifiable, CardView: View>: View {
    let slots: [Slot]
    let isLocked: (Slot) -> Bool
    let hasItem: (Slot) -> Bool
    let onSelect: ((Slot) -> Void)?
    let onView: ((Slot) -> Void)?
    let onLongPress: ((Slot) -> Void)?
    let accessibilityIdentifier: (Slot) -> String
    @ViewBuilder let card: (Slot) -> CardView

    public init(
        slots: [Slot],
        isLocked: @escaping (Slot) -> Bool,
        hasItem: @escaping (Slot) -> Bool,
        onSelect: ((Slot) -> Void)?,
        onView: ((Slot) -> Void)?,
        onLongPress: ((Slot) -> Void)? = nil,
        accessibilityIdentifier: @escaping (Slot) -> String,
        @ViewBuilder card: @escaping (Slot) -> CardView,
    ) {
        self.slots = slots
        self.isLocked = isLocked
        self.hasItem = hasItem
        self.onSelect = onSelect
        self.onView = onView
        self.onLongPress = onLongPress
        self.accessibilityIdentifier = accessibilityIdentifier
        self.card = card
    }

    public var body: some View {
        HStack(alignment: .top, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            ForEach(slots) { slot in
                let locked = isLocked(slot)
                let filled = hasItem(slot)
                if let onSelect {
                    interactiveSlot(slot, locked: locked, action: { onSelect(slot) }, inspectFilled: filled)
                } else if let onView, filled {
                    interactiveSlot(slot, locked: locked, action: { onView(slot) }, inspectFilled: true)
                } else {
                    card(slot)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .accessibilityIdentifier(accessibilityIdentifier(slot))
                }
            }
        }
    }

    private func interactiveSlot(
        _ slot: Slot,
        locked: Bool,
        action: @escaping () -> Void,
        inspectFilled: Bool,
    ) -> some View {
        InspectableTapButton(
            action: action,
            longPress: inspectAction(for: slot, locked: locked, filled: inspectFilled),
            isDisabled: locked,
            label: { card(slot) },
        )
        .trinketQuietTapButtonStyle()
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityIdentifier(accessibilityIdentifier(slot))
    }

    private func inspectAction(for slot: Slot, locked: Bool, filled: Bool) -> (() -> Void)? {
        guard !locked, filled, let onLongPress else { return nil }
        return { onLongPress(slot) }
    }
}
