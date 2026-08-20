import SwiftUI

/// Tap and long-press share one control. `Button` swallows `onLongPressGesture`;
/// a simultaneous long-press plus a skipped follow-up tap keeps both actions distinct.
public struct InspectableTapButton<Label: View>: View {
    let action: () -> Void
    var longPress: (() -> Void)?
    var isDisabled = false
    @ViewBuilder var label: () -> Label

    @State private var ignoreTap = false

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
