import SwiftUI

public extension View {
    func trinketDetailSheet(dragIndicator: Visibility = .visible) -> some View {
        modifier(TrinketDetailSheetModifier(dragIndicator: dragIndicator))
    }

    /// Sticky sheet chrome (safe-area bars) is not inside the detail `ScrollView`.
    /// Claim vertical pans so they do not dismiss the sheet; taps still win below this distance.
    func trinketSheetChromeIgnoresDismissDrag() -> some View {
        gesture(DragGesture(minimumDistance: 16))
    }
}

/// Full-height scrolling detail sheet.
///
/// System sheet (and zoom) presentation is an interruptible spring. A pan during
/// that window moves the sheet instead of the inner `ScrollView`. Interactive
/// dismiss stays off until the present spring has settled.
///
/// After settle, dismiss stays on the system grabber. Content pans prefer scrolling
/// (`.scrolls` plus always-bounce on `DetailHeroScrollShell`) so hero overscroll
/// zooms art instead of moving the sheet.
private struct TrinketDetailSheetModifier: ViewModifier {
    var dragIndicator: Visibility

    @State private var allowsInteractiveDismiss = false

    func body(content: Content) -> some View {
        content
            .presentationDetents([.large])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(dragIndicator)
            .interactiveDismissDisabled(!allowsInteractiveDismiss)
            .task {
                try? await Task.sleep(for: Self.presentationSettleDuration)
                guard !Task.isCancelled else { return }
                allowsInteractiveDismiss = true
            }
    }

    /// Typical sheet/zoom present spring; after this, grabber dismiss works again.
    private static let presentationSettleDuration: Duration = .milliseconds(550)
}
