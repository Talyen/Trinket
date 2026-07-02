import SwiftUI

struct JourneyScrollTransition: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.scrollTransition(.interactive, axis: .vertical) { view, phase in
                view
                    .scaleEffect(phase.isIdentity ? 1.03 : 0.94)
                    .blur(radius: min(abs(phase.value) * 0.75, 0.75))
            }
        } else {
            content
        }
    }
}
