import SwiftUI

public enum TrinketDesign {
    public enum Colors {
        public static let appBackground = Color(.systemBackground)
        public static let cardArtAccent = Color.accentColor
        public static let success = Color.green
        public static let destructive = Color.red
        public static let selection = Color.blue
        public static let progression = Color.yellow

        public static let health = Color.green
        public static let healthDamage = Color.red
        public static let healthTrailingDamage = Color.red.opacity(0.35)
        public static let healthRestore = Color.green

        public static let encounterBattle = Color("EncounterBattle", bundle: .main)
        public static let encounterEvent = Color("EncounterEvent", bundle: .main)
        public static let encounterShop = Color("EncounterShop", bundle: .main)
        public static let encounterRest = Color("EncounterRest", bundle: .main)
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

    public enum AppTheme: Sendable {
        case standard

        public static let `default` = AppTheme.standard

        public var palette: ThemePalette {
            ThemePalette.apple
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
