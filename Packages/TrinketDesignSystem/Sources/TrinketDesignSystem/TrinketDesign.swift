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

        /// Muted red fill for battle card bottom-edge health chrome.
        public static let battleHealth = Color.red.opacity(0.55)
        /// Subtle empty track behind battle health fill.
        public static let battleHealthTrack = Color.black.opacity(0.28)
        /// Lagging damage remnant on battle health bars.
        public static let battleHealthTrailingDamage = Color.red.opacity(0.28)

        public static let encounterBattle = DesignAssetColors.named("EncounterBattle")
        public static let encounterEvent = DesignAssetColors.named("EncounterEvent")
        public static let encounterShop = DesignAssetColors.named("EncounterShop")
        public static let encounterRest = DesignAssetColors.named("EncounterRest")
    }

    public enum Metrics {
        public static let extraSmallSpacing: CGFloat = 4
        public static let smallSpacing: CGFloat = 8
        public static let mediumSpacing: CGFloat = 12
        public static let largeSpacing: CGFloat = 16
        public static let extraLargeSpacing: CGFloat = 24
        /// Base height for two-line card captions; prefer `@ScaledMetric(relativeTo: .subheadline)`.
        public static let cardLabelReservedHeight: CGFloat = 38
        public static let statBarHeight: CGFloat = 7
        /// Thin strip height for battle card bottom-edge health chrome.
        public static let battleHealthBarHeight: CGFloat = 3
        public static let contentMargin: CGFloat = 20
        public static let contentTopPadding: CGFloat = 24
        public static let compactContentTopPadding: CGFloat = 16
        public static let sectionSpacing: CGFloat = 24
        public static let sectionHeaderSpacing: CGFloat = 10
        public static let shelfVerticalPadding: CGFloat = 4
        public static let collectionShelfHorizontalMargin: CGFloat = contentMargin
        public static let collectionShelfCardSpacing: CGFloat = 16
        public static let collectionShelfPeekRatio: CGFloat = 0.08

        /// Standard glass chip / wallet / badge inset (baked into chip modifiers).
        public static let chipPaddingHorizontal: CGFloat = 10
        public static let chipPaddingVertical: CGFloat = 6
        public static let chipCompactPaddingHorizontal: CGFloat = 8
        public static let chipCompactPaddingVertical: CGFloat = 4
        public static let chipEmphasisPaddingHorizontal: CGFloat = 14
        public static let chipEmphasisPaddingVertical: CGFloat = 9
        public static let chipUtilityPaddingHorizontal: CGFloat = 6
        public static let chipUtilityPaddingVertical: CGFloat = 3

        public static let collectionGridMinimum: CGFloat = 150
        public static let collectionGridMaximum: CGFloat = 190
        public static let partyPickerGridMinimum: CGFloat = 120
        public static let partyPickerGridMaximum: CGFloat = 160

        /// Shared adaptive columns for collection / shop item grids.
        public static var collectionGridItems: [GridItem] {
            [
                GridItem(
                    .adaptive(minimum: collectionGridMinimum, maximum: collectionGridMaximum),
                    spacing: largeSpacing
                )
            ]
        }

        /// Compact adaptive columns for party picker sheets.
        public static var partyPickerGridItems: [GridItem] {
            [
                GridItem(
                    .adaptive(minimum: partyPickerGridMinimum, maximum: partyPickerGridMaximum),
                    spacing: largeSpacing
                )
            ]
        }
    }

    public enum Corners {
        public static let small: CGFloat = 8
        public static let compact: CGFloat = 12
        public static let card: CGFloat = 16
    }

    public static let cardShape = RoundedRectangle(cornerRadius: Corners.card, style: .continuous)

    public enum AppAppearance: CaseIterable, Identifiable, RawRepresentable, Sendable {
        case system
        case light
        case dark

        public static let `default` = AppAppearance.dark

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
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
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
            case .system: nil
            case .light: .light
            case .dark: .dark
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
