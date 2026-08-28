import SwiftUI

public extension View {
    func trinketDetailSheet(dragIndicator: Visibility = .visible) -> some View {
        modifier(TrinketDetailSheetModifier(dragIndicator: dragIndicator))
    }

    func trinketSheetChromeIgnoresDismissDrag() -> some View {
        gesture(DragGesture(minimumDistance: 16))
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
                try? await Task.sleep(for: Self.presentationSettleDuration)
                guard !Task.isCancelled else { return }
                allowsInteractiveDismiss = true
            }
    }

    private static let presentationSettleDuration: Duration = .milliseconds(550)
}
