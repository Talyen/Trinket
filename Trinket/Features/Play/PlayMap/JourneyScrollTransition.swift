import SwiftUI

struct JourneyScrollTransition: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.scrollTransition(.interactive, axis: .vertical) { view, phase in
                view
                    .scaleEffect(scale(for: phase.value))
                    .blur(radius: blurRadius(for: phase.value))
            }
        } else {
            content
        }
    }

    private func scale(for phaseValue: Double) -> CGFloat {
        1.02 - easedProgress(for: phaseValue) * 0.18
    }

    private func blurRadius(for phaseValue: Double) -> CGFloat {
        easedProgress(for: phaseValue) * 1.25
    }

    private func easedProgress(for phaseValue: Double) -> CGFloat {
        let progress = min(CGFloat(abs(phaseValue)), 1)
        return progress * progress * (3 - 2 * progress)
    }
}
