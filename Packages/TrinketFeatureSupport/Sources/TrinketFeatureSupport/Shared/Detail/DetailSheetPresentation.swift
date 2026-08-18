import SwiftUI

public extension View {
    func trinketDetailSheet(dragIndicator: Visibility = .visible) -> some View {
        modifier(TrinketDetailSheetModifier(dragIndicator: dragIndicator))
    }
}

/// Full-height scrolling detail sheet.
///
/// System sheet (and zoom) presentation is an interruptible spring. A pan during
/// that window moves the sheet instead of the inner `ScrollView`. Interactive
/// dismiss stays off until the present spring has settled.
private struct TrinketDetailSheetModifier: ViewModifier {
    var dragIndicator: Visibility

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var allowsInteractiveDismiss = false

    func body(content: Content) -> some View {
        content
            .presentationDetents([.large])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(dragIndicator)
            .interactiveDismissDisabled(!allowsInteractiveDismiss)
            .task {
                if !reduceMotion {
                    try? await Task.sleep(for: Self.presentationSettleDuration)
                    guard !Task.isCancelled else { return }
                }
                allowsInteractiveDismiss = true
            }
    }

    /// Typical sheet/zoom present spring; after this, swipe-to-dismiss works again.
    private static let presentationSettleDuration: Duration = .milliseconds(550)
}
