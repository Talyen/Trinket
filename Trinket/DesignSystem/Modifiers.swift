import SwiftUI

struct FloatingGlassControlButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.glass)
    }
}

struct FloatingGlassToggleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toggleStyle(.button)
            .buttonStyle(.glass)
    }
}

struct CardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.thinMaterial)
            .clipShape(TrinketDesign.cardShape)
            .overlay {
                TrinketDesign.cardShape
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

struct CardLabelSpaceModifier: ViewModifier {
    let isReserved: Bool

    func body(content: Content) -> some View {
        if isReserved {
            content
                .frame(minHeight: TrinketDesign.Metrics.cardLabelReservedHeight, alignment: .center)
        } else {
            content
        }
    }
}

extension View {
    func trinketFloatingGlassControl() -> some View {
        modifier(FloatingGlassControlButtonModifier())
    }

    func trinketFloatingGlassToggle() -> some View {
        modifier(FloatingGlassToggleModifier())
    }

    func trinketCardSurface() -> some View {
        modifier(CardSurfaceModifier())
    }

    func trinketCardLabelSpace(_ isReserved: Bool = true) -> some View {
        modifier(CardLabelSpaceModifier(isReserved: isReserved))
    }
}

extension Color {
    static let trinketDestructive = TrinketDesign.Colors.destructive
}
