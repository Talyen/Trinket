import SwiftUI

public extension EnvironmentValues {
    @Entry var isDecorativeMotionActive = true
}

/// Pure contract behind the modifiers below, so the truth table stays pinned by tests.
enum DecorativeMotionContract {
    static func isActive(ancestor: Bool, scope: Bool) -> Bool {
        ancestor && scope
    }
}

public extension View {
    /// Enables or suppresses decorative motion (shine, plasma, aura rotation) for this subtree.
    /// Suppression composes with AND: the launch cover, tab selection, and tab prewarm each
    /// hold motion off independently, and a descendant cannot re-enable motion while any
    /// ancestor suppresses it. Flipping an ancestor back on re-enables opted-in descendants.
    func trinketDecorativeMotion(_ isActive: Bool) -> some View {
        transformEnvironment(\.isDecorativeMotionActive) {
            $0 = DecorativeMotionContract.isActive(ancestor: $0, scope: isActive)
        }
    }

    /// Retained/reveal visibility: keeps the pixels mounted (pass an explicit opacity of 1 to
    /// hold them for an instant return, as the Play browsing stack does) while removing touch,
    /// decorative motion, and accessibility exposure until visible. An explicit opacity is
    /// passed through untouched; otherwise visibility maps to 1/0.
    func trinketPresentationVisibility(_ isVisible: Bool, opacity: Double? = nil) -> some View {
        self.opacity(opacity ?? (isVisible ? 1 : 0))
            .trinketDecorativeMotion(isVisible)
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
    }
}
