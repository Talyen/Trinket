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
    let combinesAccessibilityChildren: Bool
    @ViewBuilder let card: (Slot) -> CardView

    public init(
        slots: [Slot],
        isLocked: @escaping (Slot) -> Bool,
        hasItem: @escaping (Slot) -> Bool,
        onSelect: ((Slot) -> Void)?,
        onView: ((Slot) -> Void)?,
        onLongPress: ((Slot) -> Void)? = nil,
        accessibilityIdentifier: @escaping (Slot) -> String,
        combinesAccessibilityChildren: Bool = false,
        @ViewBuilder card: @escaping (Slot) -> CardView
    ) {
        self.slots = slots
        self.isLocked = isLocked
        self.hasItem = hasItem
        self.onSelect = onSelect
        self.onView = onView
        self.onLongPress = onLongPress
        self.accessibilityIdentifier = accessibilityIdentifier
        self.combinesAccessibilityChildren = combinesAccessibilityChildren
        self.card = card
    }

    public var body: some View {
        HStack(alignment: .top, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            ForEach(slots) { slot in
                let locked = isLocked(slot)
                if let onSelect {
                    InspectableTapButton(
                        action: { onSelect(slot) },
                        longPress: inspectAction(for: slot, locked: locked, filled: hasItem(slot)),
                        isDisabled: locked,
                        label: { card(slot) }
                    )
                    .trinketQuietTapButtonStyle()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .trinketAccessibilityCombine(combinesAccessibilityChildren)
                    .accessibilityIdentifier(accessibilityIdentifier(slot))

                } else if let onView, hasItem(slot) {
                    InspectableTapButton(
                        action: { onView(slot) },
                        longPress: inspectAction(for: slot, locked: locked, filled: true),
                        isDisabled: locked,
                        label: { card(slot) }
                    )
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

    private func inspectAction(for slot: Slot, locked: Bool, filled: Bool) -> (() -> Void)? {
        guard !locked, filled, let onLongPress else { return nil }
        return { onLongPress(slot) }
    }
}

/// Tap and long-press share one control. `Button` swallows `onLongPressGesture`;
/// a simultaneous long-press plus a skipped follow-up tap keeps both actions distinct.
struct InspectableTapButton<Label: View>: View {
    let action: () -> Void
    var longPress: (() -> Void)?
    var isDisabled = false
    @ViewBuilder var label: () -> Label

    @State private var ignoreTap = false

    var body: some View {
        Button {
            if ignoreTap {
                ignoreTap = false
                return
            }
            action()
        } label: {
            label()
        }
        .disabled(isDisabled)
        .modifier(InspectLongPressModifier(longPress: isDisabled ? nil : longPress, ignoreTap: $ignoreTap))
    }
}

private struct InspectLongPressModifier: ViewModifier {
    let longPress: (() -> Void)?
    @Binding var ignoreTap: Bool

    func body(content: Content) -> some View {
        if let longPress {
            content
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            ignoreTap = true
                            longPress()
                        }
                )
                .accessibilityAction(named: "Show Details", longPress)
        } else {
            content
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
