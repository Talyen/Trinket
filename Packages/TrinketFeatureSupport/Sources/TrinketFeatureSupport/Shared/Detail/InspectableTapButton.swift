import SwiftUI

public struct InspectableTapButton<Label: View>: View {
    let action: () -> Void
    var longPress: (() -> Void)?
    let isActionEnabled: Bool
    let isInspectionEnabled: Bool
    @ViewBuilder var label: () -> Label
    @State private var suppressAction = false

    public init(
        action: @escaping () -> Void,
        longPress: (() -> Void)? = nil,
        isActionEnabled: Bool = true,
        isInspectionEnabled: Bool = true,
        @ViewBuilder label: @escaping () -> Label,
    ) {
        self.action = action
        self.longPress = longPress
        self.isActionEnabled = isActionEnabled
        self.isInspectionEnabled = isInspectionEnabled
        self.label = label
    }

    public var body: some View {
        Button {
            // A successful long press must not also perform the slot's tap action.
            guard !suppressAction else {
                suppressAction = false
                return
            }
            if isActionEnabled {
                action()
            } else if isInspectionEnabled {
                longPress?()
            }
        } label: {
            label()
        }
        .disabled(!isActionEnabled && (!isInspectionEnabled || longPress == nil))
        .modifier(InspectLongPressModifier(
            longPress: isInspectionEnabled ? longPress : nil,
            suppressAction: $suppressAction,
        ))
    }
}

private struct InspectLongPressModifier: ViewModifier {
    let longPress: (() -> Void)?
    @Binding var suppressAction: Bool

    func body(content: Content) -> some View {
        if let longPress {
            content.onLongPressGesture(minimumDuration: 0.5) {
                suppressAction = true
                longPress()
            } onPressingChanged: { pressing in
                if pressing {
                    suppressAction = false
                }
            }
        } else {
            content
        }
    }
}
