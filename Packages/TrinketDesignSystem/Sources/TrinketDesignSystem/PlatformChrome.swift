import SwiftUI

public extension View {
    @ViewBuilder
    func trinketSoftTopScrollEdge(isHidden: Bool? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let isHidden {
                scrollEdgeEffectHidden(isHidden, for: .top)
                    .scrollEdgeEffectStyle(.soft, for: .top)
            } else {
                scrollEdgeEffectStyle(.soft, for: .top)
            }
        } else {
            self
        }
    }
}

public extension ToolbarContent {
    @ToolbarContentBuilder
    func trinketToolbarBackgroundHidden() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
