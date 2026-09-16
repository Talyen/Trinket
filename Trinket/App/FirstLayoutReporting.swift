import SwiftUI

/// Shared nonzero-layout acknowledgement for launch-gated surfaces.
///
/// Replaces five copies of `onGeometryChange(width > 0 && height > 0)`.
/// Task yields and elapsed time are not layout acknowledgements; only a real
/// nonzero size counts (see ui-performance launch rules).
extension View {
    func onFirstNonzeroLayout(perform: @escaping () -> Void) -> some View {
        modifier(FirstNonzeroLayoutModifier(enabled: true, perform: perform))
    }

    func onFirstNonzeroLayout(when enabled: Bool, perform: @escaping () -> Void) -> some View {
        modifier(FirstNonzeroLayoutModifier(enabled: enabled, perform: perform))
    }
}

private struct FirstNonzeroLayoutModifier: ViewModifier {
    let enabled: Bool
    let perform: () -> Void
    @State private var hasTriggered = false

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Bool.self) { geometry in
                !hasTriggered && enabled && geometry.size.width > 0 && geometry.size.height > 0
            } action: { hasLayout in
                if hasLayout, !hasTriggered {
                    hasTriggered = true
                    perform()
                }
            }
    }
}
