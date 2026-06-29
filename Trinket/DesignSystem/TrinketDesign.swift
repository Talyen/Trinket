import SwiftUI

enum TrinketDesign {

    enum Colors {
        static let appBackground = Color(.systemBackground)
        static let cardArtAccent = Color.accentColor
        static let success = Color.green
        static let destructive = Color.red
        static let selection = Color.blue
        static let progression = Color.blue

        static let healthDamage = Color.red
        static let healthTrailingDamage = Color.red.opacity(0.35)
        static let healthRestore = Color.green
    }

    enum Metrics {
        static let cardLabelReservedHeight: CGFloat = 38
    }

    static let cardShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    enum AppTheme: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

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
}

extension View {
    func trinketFloatingGlassControl() -> some View {
        modifier(TrinketDesign.FloatingGlassControlButtonModifier())
    }

    func trinketFloatingGlassToggle() -> some View {
        modifier(TrinketDesign.FloatingGlassToggleModifier())
    }

    func trinketCardSurface() -> some View {
        modifier(TrinketDesign.CardSurfaceModifier())
    }
}

extension Color {
    static let trinketDestructive = TrinketDesign.Colors.destructive
}
