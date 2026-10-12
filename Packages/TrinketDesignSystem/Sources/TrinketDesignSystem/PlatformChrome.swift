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

    @ViewBuilder
    func trinketToolbarBackgroundHidden(
        @ToolbarContentBuilder content: () -> some ToolbarContent,
    ) -> some View {
        // Keep availability outside ToolbarContentBuilder: SDK 27.1 beta's
        // optimized device linker cannot resolve its limited-availability type.
        if #available(iOS 26.0, *) {
            toolbar {
                content().sharedBackgroundVisibility(.hidden)
            }
        } else {
            toolbar(content: content)
        }
    }
}
