import SwiftUI

public enum TrinketDetailSheetMetrics {
    public static let presentationSettleDuration: Duration = .milliseconds(550)
    public static let dismissDragThreshold: CGFloat = 16
}

public extension View {
    func trinketDetailSheet(dragIndicator: Visibility = .visible) -> some View {
        modifier(TrinketDetailSheetModifier(dragIndicator: dragIndicator))
    }

    func trinketSheetChromeIgnoresDismissDrag(minimumDistance: CGFloat = TrinketDetailSheetMetrics.dismissDragThreshold) -> some View {
        gesture(DragGesture(minimumDistance: minimumDistance))
    }
}

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
                try? await Task.sleep(for: TrinketDetailSheetMetrics.presentationSettleDuration)
                guard !Task.isCancelled else { return }
                allowsInteractiveDismiss = true
            }
    }
}
