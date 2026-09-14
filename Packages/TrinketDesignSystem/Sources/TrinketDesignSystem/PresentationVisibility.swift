import SwiftUI

public extension EnvironmentValues {
    @Entry var isDecorativeMotionActive = true
}

public extension View {
    func trinketDecorativeMotion(_ isActive: Bool) -> some View {
        transformEnvironment(\.isDecorativeMotionActive) { $0 = $0 && isActive }
    }

    func trinketPresentationVisibility(_ isVisible: Bool, opacity: Double? = nil) -> some View {
        self.opacity(opacity ?? (isVisible ? 1 : 0))
            .trinketDecorativeMotion(isVisible)
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
    }
}
