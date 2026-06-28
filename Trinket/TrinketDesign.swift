import SwiftUI

enum TrinketDesign {
    static let cardCornerRadius: CGFloat = 12

    static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
    }

    enum AppTheme: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var id: String { self.rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    enum Colors {
        static var appBackground: Color { Color(.systemGroupedBackground) }
        static var groupedSurface: Color { Color(.secondarySystemGroupedBackground) }
        static var selection: Color { .accentColor }
        static var success: Color { .green }
        static var caution: Color { .orange }
        static var destructive: Color { .red }
        static var cardArtAccent: Color { .blue }
        static var progression: Color { .indigo }
        static var healthRestore: Color { .green.opacity(0.45) }
        static var healthTrailingDamage: Color { .orange.opacity(0.45) }
        static var equippedBackground: Color { success.opacity(0.12) }
        static var equippedStroke: Color { success.opacity(0.28) }

        static func health(for role: Combatant.Role) -> Color {
            role == .enemy ? .red : .blue
        }
    }

    enum Materials {
        static var card: Material { .regularMaterial }
        static var feedback: Material { .thinMaterial }
    }

    struct KeywordStyle {
        let color: Color
        let symbolName: String

        var cardTint: Color { color.opacity(0.24) }
        var feedbackStroke: Color { color.opacity(0.28) }
        var feedbackShadow: Color { color.opacity(0.25) }
    }

    struct ItemSlotStyle {
        let accentColor: Color
    }

    struct FloatingGlassControlButtonModifier: ViewModifier {
        func body(content: Content) -> some View {
            if #available(iOS 26.0, *) {
                content
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.regular)
            } else {
                content
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.regular)
            }
        }
    }

    struct FloatingGlassToggleModifier: ViewModifier {
        func body(content: Content) -> some View {
            if #available(iOS 26.0, *) {
                content
                    .toggleStyle(.button)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.regular)
                    .tint(Colors.selection)
            } else {
                content
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.regular)
                    .tint(Colors.selection)
            }
        }
    }

    struct CardSurfaceModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .background(Materials.card, in: cardShape)
                .overlay {
                    cardShape
                        .stroke(.quaternary, lineWidth: 1)
                }
        }
    }
}

extension Keyword {
    var visualStyle: TrinketDesign.KeywordStyle {
        switch self {
        case .physical:
            return TrinketDesign.KeywordStyle(color: .primary, symbolName: "burst.fill")
        case .burn:
            return TrinketDesign.KeywordStyle(color: .orange, symbolName: "flame.fill")
        }
    }
}

extension Combatant {
    var healthBarColor: Color {
        TrinketDesign.Colors.health(for: role)
    }
}

extension ItemSlot {
    var visualStyle: TrinketDesign.ItemSlotStyle {
        switch self {
        case .weapon:
            return TrinketDesign.ItemSlotStyle(accentColor: .orange)
        case .armor:
            return TrinketDesign.ItemSlotStyle(accentColor: .blue)
        case .trinket:
            return TrinketDesign.ItemSlotStyle(accentColor: .purple)
        }
    }
}
