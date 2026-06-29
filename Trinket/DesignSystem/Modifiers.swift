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
            .background(.regularMaterial)
            .clipShape(TrinketDesign.cardShape)
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
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
}

extension Color {
    static let trinketDestructive = TrinketDesign.Colors.destructive
}
