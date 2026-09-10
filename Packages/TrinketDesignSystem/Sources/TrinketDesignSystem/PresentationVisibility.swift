import SwiftUI

public extension View {
    func trinketPresentationVisibility(_ isVisible: Bool, opacity: Double? = nil) -> some View {
        self.opacity(opacity ?? (isVisible ? 1 : 0))
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
    }
}
