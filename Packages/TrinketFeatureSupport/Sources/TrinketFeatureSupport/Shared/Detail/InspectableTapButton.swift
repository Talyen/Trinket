import SwiftUI

/// Tap and long-press share one control. Quick releases never complete the
/// long-press, and every inspection presents modally, which cancels the
/// pending lift-tap — so the actions stay distinct without tap bookkeeping.
public struct InspectableTapButton<Label: View>: View {
    let action: () -> Void
    var longPress: (() -> Void)?
    var isDisabled = false
    @ViewBuilder var label: () -> Label

    public init(
        action: @escaping () -> Void,
        longPress: (() -> Void)? = nil,
        isDisabled: Bool = false,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.longPress = longPress
        self.isDisabled = isDisabled
        self.label = label
    }

    public var body: some View {
        Button(action: action) {
            label()
        }
        .disabled(isDisabled)
        .modifier(InspectLongPressModifier(longPress: isDisabled ? nil : longPress))
    }
}

private struct InspectLongPressModifier: ViewModifier {
    let longPress: (() -> Void)?

    func body(content: Content) -> some View {
        if let longPress {
            content
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in longPress() }
                )
                .accessibilityAction(named: "Show Details", longPress)
        } else {
            content
        }
    }
}
