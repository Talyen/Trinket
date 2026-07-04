import SwiftUI

struct JourneyScrollTransition: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.scrollTransition(.interactive, axis: .vertical) { view, phase in
                view
                    .scaleEffect(1.06 - min(abs(phase.value), 1) * 0.18)
                    .blur(radius: min(abs(phase.value), 1) * 2.0)
            }
        } else {
            content
        }
    }
}
