import SwiftUI

public struct InspectableTapButton<Label: View>: View {
    let action: () -> Void
    var longPress: (() -> Void)?
    let isActionEnabled: Bool
    let isInspectionEnabled: Bool
    @ViewBuilder var label: () -> Label

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
            if isActionEnabled {
                action()
            } else if isInspectionEnabled {
                longPress?()
            }
        } label: {
            label()
        }
        .disabled(!isActionEnabled && (!isInspectionEnabled || longPress == nil))
        .modifier(InspectLongPressModifier(longPress: isInspectionEnabled ? longPress : nil))
    }
}

private struct InspectLongPressModifier: ViewModifier {
    let longPress: (() -> Void)?

    func body(content: Content) -> some View {
        if let longPress {
            content
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in longPress() },
                )
        } else {
            content
        }
    }
}
