import SwiftUI

public enum TrinketDesign {
    public enum Colors {
        public static let appBackground = AppTheme.default.palette.appBackground
        public static let cardArtAccent = Color.accentColor
        public static let success = Color.green
        public static let destructive = Color.red
        public static let selection = Color.blue
        public static let progression = Color.yellow

        public static let health = Color.green
        public static let healthDamage = Color.red
        public static let healthTrailingDamage = Color.red.opacity(0.35)
        public static let healthRestore = Color.green

        public static let encounterBattle = Color(red: 0.86, green: 0.18, blue: 0.16)
        public static let encounterEvent = Color(red: 0.46, green: 0.36, blue: 0.86)
        public static let encounterShop = Color(red: 0.88, green: 0.48, blue: 0.16)
        public static let encounterRest = Color(red: 0.10, green: 0.64, blue: 0.58)
    }

    public enum Metrics {
        public static let extraSmallSpacing: CGFloat = 4
        public static let smallSpacing: CGFloat = 8
        public static let mediumSpacing: CGFloat = 12
        public static let largeSpacing: CGFloat = 16
        public static let extraLargeSpacing: CGFloat = 24
        public static let cardLabelReservedHeight: CGFloat = 38
        public static let statBarHeight: CGFloat = 7
        public static let contentMargin: CGFloat = 20
        public static let contentTopPadding: CGFloat = 24
        public static let compactContentTopPadding: CGFloat = 16
        public static let sectionSpacing: CGFloat = 24
        public static let sectionHeaderSpacing: CGFloat = 10
        public static let shelfVerticalPadding: CGFloat = 4
        public static let collectionShelfHorizontalMargin: CGFloat = contentMargin
        public static let collectionShelfCardSpacing: CGFloat = 16
        public static let collectionShelfPeekRatio: CGFloat = 0.08
    }

    public enum Corners {
        public static let small: CGFloat = 8
        public static let compact: CGFloat = 12
        public static let card: CGFloat = 16
    }

    public static let cardShape = RoundedRectangle(cornerRadius: Corners.card, style: .continuous)

    public enum AppTheme: CaseIterable, Identifiable, RawRepresentable, Sendable {
        case darkTabletop
        case warmParchment
        case arcaneNight
        case forestAlchemy

        public static let `default` = AppTheme.darkTabletop

        public init?(rawValue: String) {
            let normalized = rawValue
                .lowercased()
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            switch normalized {
            case "graphite", "dark tabletop", "dark", "system native", "system":
                self = .darkTabletop
            case "parchment", "warm parchment", "light":
                self = .warmParchment
            case "obsidian", "arcane night", "arcane":
                self = .arcaneNight
            case "linen", "stone linen", "forest alchemy", "forest":
                self = .forestAlchemy
            default:
                return nil
            }
        }

        public var rawValue: String {
            switch self {
            case .darkTabletop: return "Graphite"
            case .warmParchment: return "Parchment"
            case .arcaneNight: return "Obsidian"
            case .forestAlchemy: return "Linen"
            }
        }

        public var id: String {
            rawValue
        }

        public var displayName: String {
            rawValue
        }

        public var palette: ThemePalette {
            switch self {
            case .darkTabletop: return ThemePalette.darkTabletop.systemCanvasPalette()
            case .warmParchment: return ThemePalette.warmParchment.systemCanvasPalette()
            case .arcaneNight: return ThemePalette.arcaneNight.systemCanvasPalette()
            case .forestAlchemy: return ThemePalette.forestAlchemy.systemCanvasPalette()
            }
        }
    }

    public enum AppAppearance: CaseIterable, Identifiable, RawRepresentable, Sendable {
        case system
        case light
        case dark

        public static let `default` = AppAppearance.system

        public init?(rawValue: String) {
            let normalized = rawValue
                .lowercased()
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            switch normalized {
            case "system", "system default", "automatic":
                self = .system
            case "light":
                self = .light
            case "dark":
                self = .dark
            default:
                return nil
            }
        }

        public var rawValue: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        public var id: String {
            rawValue
        }

        public var displayName: String {
            rawValue
        }

        public var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    public struct CardPlaceholderStyle: Sendable {
        public let color: Color
        public let symbolName: String

        public static let hero = CardPlaceholderStyle(color: .blue, symbolName: "person.fill")
        public static let pet = CardPlaceholderStyle(color: .green, symbolName: "pawprint.fill")
        public static let enemy = CardPlaceholderStyle(color: .red, symbolName: "flame.fill")
        public static let item = CardPlaceholderStyle(color: .orange, symbolName: "shippingbox.fill")
        public static let ability = CardPlaceholderStyle(color: .indigo, symbolName: "bolt.fill")
    }
}

public extension View {
    func collectionShelfCardWidth() -> some View {
        containerRelativeFrame(.horizontal) { length, _ in
            let margin = TrinketDesign.Metrics.collectionShelfHorizontalMargin
            let spacing = TrinketDesign.Metrics.collectionShelfCardSpacing
            let peek = TrinketDesign.Metrics.collectionShelfPeekRatio
            return (length - 2 * margin - spacing) / (1.75 + peek)
        }
    }
}
