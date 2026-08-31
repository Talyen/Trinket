import SwiftUI

public enum TrinketDesign {
    public enum Colors {
        public static let canvas = DesignAssetColors.named("ThemeCanvas")
        public static let surface = DesignAssetColors.named("ThemeSurface")
        public static let panel = DesignAssetColors.named("ThemePanel")
        public static let elevated = DesignAssetColors.named("ThemeElevated")
        public static let subtleStroke = DesignAssetColors.named("ThemeSubtleStroke")

        public static let accent = DesignAssetColors.named("ThemeAntiqueGold")
        public static let accentEmphasized = DesignAssetColors.named("ThemeHighlightGold")
        public static let accentPressed = DesignAssetColors.named("ThemePressedGold")
        public static let success = DesignAssetColors.named("ThemeSuccess")
        public static let warning = DesignAssetColors.named("ThemeWarning")
        public static let destructive = DesignAssetColors.named("ThemeDestructive")
        public static let informational = DesignAssetColors.named("ThemeInformational")
        public static let arcane = DesignAssetColors.named("ThemeArcane")

        public static let health = DesignAssetColors.named("ThemeHealth")
        public static let healthRestore = DesignAssetColors.named("ThemeHealthRestore")
        public static let healthTrailingDamage = health.opacity(0.35)

        public static let battleHealth = health.opacity(0.92)
        public static let battleHealthTrack = Overlay.ink.opacity(0.62)
        public static let battleHealthTrailingDamage = health.opacity(0.45)
        public static let battleSliceCrack = DesignAssetColors.named("BattleSliceCrack")
        public static let battleSliceSpark = DesignAssetColors.named("BattleSliceSpark")

        public static let encounterBattle = DesignAssetColors.named("EncounterBattle")
        public static let encounterEvent = DesignAssetColors.named("EncounterEvent")
        public static let encounterShop = DesignAssetColors.named("EncounterShop")
        public static let encounterRest = DesignAssetColors.named("EncounterRest")

        public static let chapterForest = DesignAssetColors.named("ChapterForest")
        public static let chapterDungeon = DesignAssetColors.named("ChapterDungeon")
        public static let chapterDesert = DesignAssetColors.named("ChapterDesert")
        public static let chapterTundra = DesignAssetColors.named("ChapterTundra")

        public enum Overlay {
            public static let ink = DesignAssetColors.named("ThemeOverlayInk")
            public static let paper = DesignAssetColors.named("ThemeOverlayPaper")
            public static let dragShadow = ink.opacity(0.3)
            public static let cinematicDim = ink
        }
    }

    public enum Metrics {
        public static let tightSpacing: CGFloat = 2
        public static let extraSmallSpacing: CGFloat = 4
        public static let smallSpacing: CGFloat = 8
        public static let mediumSpacing: CGFloat = 12
        public static let largeSpacing: CGFloat = 16
        public static let extraLargeSpacing: CGFloat = 24
        public static let cardLabelReservedHeight: CGFloat = 38
        public static let cardPlaceholderIconPointSize: CGFloat = 38
        public static let walletResourceArtworkSize: CGFloat = 36
        public static let compactResourceArtworkSize: CGFloat = 20
        public static let walletResourceRowMinHeight: CGFloat = 46
        public static let mysteryRewardArtworkSize: CGFloat = 44
        public static let mysteryRewardRowMinHeight: CGFloat = 48
        public static let statBarHeight: CGFloat = 7
        public static let battleHealthBarHeight: CGFloat = 3
        public static let battleHealthBarActiveHeight: CGFloat = 7
        public static let contentMargin: CGFloat = 20
        public static let singlePrimaryActionWidthFraction: CGFloat = 0.5
        public static let contentTopPadding: CGFloat = 24
        public static let compactContentTopPadding: CGFloat = 16
        public static let sectionSpacing: CGFloat = 24
        public static let sectionHeaderSpacing: CGFloat = 8
        public static let shelfVerticalPadding: CGFloat = 4
        public static let collectionShelfHorizontalMargin: CGFloat = contentMargin
        public static let collectionShelfCardSpacing: CGFloat = 16
        public static let collectionShelfPeekRatio: CGFloat = 0.08
        public static let collectionShelfPreviewLimit = 8
        public static let tabBarContentClearance: CGFloat = 112
        public static let compactTabBarContentClearance: CGFloat = 92

        public static let chipPaddingHorizontal: CGFloat = 10
        public static let chipPaddingVertical: CGFloat = smallSpacing
        public static let chipEmphasisPaddingHorizontal: CGFloat = largeSpacing
        public static let chipEmphasisPaddingVertical: CGFloat = smallSpacing

        public static let collectionGridMinimum: CGFloat = 150
        public static let collectionGridMaximum: CGFloat = 190
        public static let partyPickerGridMinimum: CGFloat = 120
        public static let partyPickerGridMaximum: CGFloat = 160

        public static var collectionGridItems: [GridItem] {
            [
                GridItem(
                    .adaptive(minimum: collectionGridMinimum, maximum: collectionGridMaximum),
                    spacing: largeSpacing,
                ),
            ]
        }

        public static var partyPickerGridItems: [GridItem] {
            [
                GridItem(
                    .adaptive(minimum: partyPickerGridMinimum, maximum: partyPickerGridMaximum),
                    spacing: largeSpacing,
                ),
            ]
        }

        public static func hubGridItems(for horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
            if horizontalSizeClass == .regular {
                return [
                    GridItem(.flexible(), spacing: largeSpacing),
                    GridItem(.flexible(), spacing: largeSpacing),
                ]
            }
            return [GridItem(.flexible())]
        }
    }

    public enum Corners {
        public static let card: CGFloat = 16
    }

    public static let cardShape = RoundedRectangle(cornerRadius: Corners.card, style: .continuous)

    public struct CardPlaceholderStyle: Sendable {
        public let color: Color
        public let symbolName: String

        public static let hero = Self(
            color: DesignAssetColors.named("PlaceholderHero"),
            symbolName: "person.fill",
        )
        public static let companion = Self(
            color: DesignAssetColors.named("PlaceholderCompanion"),
            symbolName: "pawprint.fill",
        )
        public static let enemy = Self(
            color: DesignAssetColors.named("PlaceholderEnemy"),
            symbolName: "flame.fill",
        )
        public static let item = Self(
            color: DesignAssetColors.named("PlaceholderItem"),
            symbolName: "shippingbox.fill",
        )
        public static let ability = Self(
            color: DesignAssetColors.named("PlaceholderAbility"),
            symbolName: "bolt.fill",
        )
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
