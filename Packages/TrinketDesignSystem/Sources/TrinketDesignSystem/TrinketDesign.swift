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
        public static let healthTrailingDamage = health.opacity(Opacity.trailingDamage)
        public static let battleHealth = health.opacity(Opacity.battleHealth)
        public static let battleHealthTrack = Overlay.ink.opacity(Opacity.glow)
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
            public static let dragShadow = ink.opacity(Opacity.dragShadow)
            public static let cinematicDim = ink
        }
    }

    public enum Opacity {
        public static let subtle: Double = 0.14
        public static let border: Double = 0.48
        public static let glow: Double = 0.62
        public static let secondary: Double = 0.72
        public static let dragShadow: Double = 0.3
        public static let trailingDamage: Double = 0.35
        public static let battleHealth: Double = 0.92
        public static let placeholderWash: Double = 0.18
        public static let cardPlaceholderPaper: Double = 0.85
    }

    public enum Spacing {
        public static let tight: CGFloat = 2
        public static let extraSmall: CGFloat = 4
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let extraLarge: CGFloat = 24
    }

    public enum Layout {
        public static let contentMargin: CGFloat = 20
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
        public static let chipPaddingVertical: CGFloat = Spacing.small
        public static let chipEmphasisPaddingHorizontal: CGFloat = Spacing.large
        public static let chipEmphasisPaddingVertical: CGFloat = Spacing.small
        public static let collectionGridMinimum: CGFloat = 150
        public static let collectionGridMaximum: CGFloat = 190
        public static let partyPickerGridMinimum: CGFloat = 120
        public static let partyPickerGridMaximum: CGFloat = 160

        public static var collectionGridItems: [GridItem] {
            [GridItem(.adaptive(minimum: collectionGridMinimum, maximum: collectionGridMaximum), spacing: Spacing.large)]
        }

        public static var partyPickerGridItems: [GridItem] {
            [GridItem(.adaptive(minimum: partyPickerGridMinimum, maximum: partyPickerGridMaximum), spacing: Spacing.large)]
        }

        public static func hubGridItems(for horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
            if horizontalSizeClass == .regular {
                return [GridItem(.flexible(), spacing: Spacing.large), GridItem(.flexible(), spacing: Spacing.large)]
            }
            return [GridItem(.flexible())]
        }
    }

    public enum Bars {
        public static let vitalHeight: CGFloat = 3
        public static let statHeight: CGFloat = 7
        public static let battleHeight: CGFloat = vitalHeight
    }

    @available(*, deprecated, message: "Use TrinketDesign.Spacing, TrinketDesign.Layout, or TrinketDesign.Bars instead")
    public enum Metrics {
        public static let tightSpacing: CGFloat = Spacing.tight
        public static let extraSmallSpacing: CGFloat = Spacing.extraSmall
        public static let smallSpacing: CGFloat = Spacing.small
        public static let mediumSpacing: CGFloat = Spacing.medium
        public static let largeSpacing: CGFloat = Spacing.large
        public static let extraLargeSpacing: CGFloat = Spacing.extraLarge
        public static let cardLabelReservedHeight: CGFloat = 38
        public static let cardPlaceholderIconPointSize: CGFloat = 38
        public static let walletResourceArtworkSize: CGFloat = 36
        public static let compactResourceArtworkSize: CGFloat = 20
        public static let walletResourceRowMinHeight: CGFloat = 46
        public static let mysteryRewardArtworkSize: CGFloat = 44
        public static let mysteryRewardRowMinHeight: CGFloat = 48
        public static let statBarHeight: CGFloat = Bars.statHeight
        public static let battleHealthBarHeight: CGFloat = Bars.battleHeight
        public static let battleHealthBarActiveHeight: CGFloat = Bars.battleHeight
        public static let contentMargin: CGFloat = Layout.contentMargin
        public static let singlePrimaryActionWidthFraction: CGFloat = 0.5
        public static let contentTopPadding: CGFloat = Layout.contentTopPadding
        public static let compactContentTopPadding: CGFloat = Layout.compactContentTopPadding
        public static let sectionSpacing: CGFloat = Layout.sectionSpacing
        public static let sectionHeaderSpacing: CGFloat = Layout.sectionHeaderSpacing
        public static let shelfVerticalPadding: CGFloat = Layout.shelfVerticalPadding
        public static let collectionShelfHorizontalMargin: CGFloat = Layout.collectionShelfHorizontalMargin
        public static let collectionShelfCardSpacing: CGFloat = Layout.collectionShelfCardSpacing
        public static let collectionShelfPeekRatio: CGFloat = Layout.collectionShelfPeekRatio
        public static let collectionShelfPreviewLimit = Layout.collectionShelfPreviewLimit
        public static let tabBarContentClearance: CGFloat = Layout.tabBarContentClearance
        public static let compactTabBarContentClearance: CGFloat = Layout.compactTabBarContentClearance
        public static let chipPaddingHorizontal: CGFloat = Layout.chipPaddingHorizontal
        public static let chipPaddingVertical: CGFloat = Layout.chipPaddingVertical
        public static let chipEmphasisPaddingHorizontal: CGFloat = Layout.chipEmphasisPaddingHorizontal
        public static let chipEmphasisPaddingVertical: CGFloat = Layout.chipEmphasisPaddingVertical
        public static let collectionGridMinimum: CGFloat = Layout.collectionGridMinimum
        public static let collectionGridMaximum: CGFloat = Layout.collectionGridMaximum
        public static let partyPickerGridMinimum: CGFloat = Layout.partyPickerGridMinimum
        public static let partyPickerGridMaximum: CGFloat = Layout.partyPickerGridMaximum
        public static var collectionGridItems: [GridItem] {
            Layout.collectionGridItems
        }

        public static var partyPickerGridItems: [GridItem] {
            Layout.partyPickerGridItems
        }

        public static func hubGridItems(for horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
            Layout
                .hubGridItems(for: horizontalSizeClass)
        }
    }

    public enum Corners {
        public static let card: CGFloat = 16
    }

    public static let cardShape = RoundedRectangle(cornerRadius: Corners.card, style: .continuous)

    public struct CardPlaceholderStyle: Sendable {
        public let color: Color
        public let symbolName: String

        public static let hero = Self(color: DesignAssetColors.named("PlaceholderHero"), symbolName: "person.fill")
        public static let companion = Self(color: DesignAssetColors.named("PlaceholderCompanion"), symbolName: "pawprint.fill")
        public static let enemy = Self(color: DesignAssetColors.named("PlaceholderEnemy"), symbolName: "flame.fill")
        public static let item = Self(color: DesignAssetColors.named("PlaceholderItem"), symbolName: "shippingbox.fill")
        public static let ability = Self(color: DesignAssetColors.named("PlaceholderAbility"), symbolName: "bolt.fill")
    }
}
