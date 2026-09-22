import SwiftUI

public enum TrinketDesign {
    public enum Colors {
        public static let canvas = DesignAssetColors.named("ThemeCanvas")
        public static let surface = DesignAssetColors.named("ThemeSurface")
        public static let panel = DesignAssetColors.named("ThemePanel")
        public static let sheet = panel
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
        public static let battleHealth = health.opacity(Opacity.battleHealth)
        public static let battleHealthTrack = Overlay.ink.opacity(Opacity.glow)
        public static let battleHealthTrailingDamage = health.opacity(Opacity.trailingDamage)
        public static let battleSliceCrack = DesignAssetColors.named("BattleSliceCrack")
        public static let battleSliceSpark = DesignAssetColors.named("BattleSliceSpark")

        public static let encounterBattle = DesignAssetColors.named("EncounterBattle")
        public static let encounterEvent = DesignAssetColors.named("EncounterEvent")
        public static let encounterShop = DesignAssetColors.named("EncounterShop")

        public static let chapterForest = DesignAssetColors.named("ChapterForest")
        public static let chapterDungeon = DesignAssetColors.named("ChapterDungeon")
        public static let chapterDesert = DesignAssetColors.named("ChapterDesert")
        public static let chapterTundra = DesignAssetColors.named("ChapterTundra")

        // Keyword identity colors. `gold` aliases `accent` and `thorns` aliases
        // `keywordPhysical`, so neither has a dedicated token here.
        public static let keywordPhysical = DesignAssetColors.named("KeywordPhysical")
        public static let keywordBurn = DesignAssetColors.named("KeywordBurn")
        public static let keywordStun = DesignAssetColors.named("KeywordStun")
        public static let keywordBlock = DesignAssetColors.named("KeywordBlock")
        public static let keywordHealth = DesignAssetColors.named("KeywordHealth")
        public static let keywordHoly = DesignAssetColors.named("KeywordHoly")
        public static let keywordPoison = DesignAssetColors.named("KeywordPoison")
        public static let keywordBleed = DesignAssetColors.named("KeywordBleed")
        public static let keywordLeech = DesignAssetColors.named("KeywordLeech")
        public static let keywordFreeze = DesignAssetColors.named("KeywordFreeze")
        public static let keywordDodge = DesignAssetColors.named("KeywordDodge")
        public static let keywordPurge = DesignAssetColors.named("KeywordPurge")
        public static let keywordCleanse = DesignAssetColors.named("KeywordCleanse")
        public static let keywordMana = DesignAssetColors.named("KeywordMana")
        public static let keywordDeathsDoor = DesignAssetColors.named("KeywordDeathsDoor")

        // Homestead resource tints. `gold` aliases `accent`.
        public static let resourceWood = DesignAssetColors.named("ResourceWood")
        public static let resourceStone = DesignAssetColors.named("ResourceStone")
        public static let resourceIron = DesignAssetColors.named("ResourceIron")
        public static let resourceFood = DesignAssetColors.named("ResourceFood")
        public static let resourceHerbs = DesignAssetColors.named("ResourceHerbs")
        public static let resourceHide = DesignAssetColors.named("ResourceHide")
        public static let resourceGems = DesignAssetColors.named("ResourceGems")

        public static let placeholderHero = DesignAssetColors.named("PlaceholderHero")
        public static let placeholderCompanion = DesignAssetColors.named("PlaceholderCompanion")
        public static let placeholderEnemy = DesignAssetColors.named("PlaceholderEnemy")
        public static let placeholderItem = DesignAssetColors.named("PlaceholderItem")
        public static let placeholderAbility = DesignAssetColors.named("PlaceholderAbility")

        public enum Overlay {
            public static let ink = DesignAssetColors.named("ThemeOverlayInk")
            public static let paper = DesignAssetColors.named("ThemeOverlayPaper")
            public static let dragShadow = ink.opacity(Opacity.dragShadow)
            public static let cinematicDim = ink.opacity(Opacity.cinematicDim)
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
        public static let cinematicDim: Double = 0.6
        public static let chipEmphasisStroke: Double = 0.22
        /// Dimmed duplicate of a color inside shine gradients.
        public static let shineDim: Double = 0.55
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
        public static let collectionShelfCardSpacing: CGFloat = Spacing.large
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
        public static let cardLabelReservedHeight: CGFloat = 38
        public static let cardPlaceholderIconPointSize: CGFloat = 38
        public static let walletResourceArtworkSize: CGFloat = 36
        public static let compactResourceArtworkSize: CGFloat = 20
        public static let walletResourceRowMinHeight: CGFloat = 46
        public static let mysteryRewardArtworkSize: CGFloat = 44
        public static let mysteryRewardRowMinHeight: CGFloat = 48
        public static let singlePrimaryActionWidthFraction: CGFloat = 0.5
        public static let collectionShelfVisibleCardCount: CGFloat = 1.75

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

    public enum Corners {
        public static let card: CGFloat = 16
    }

    public static let cardShape = RoundedRectangle(cornerRadius: Corners.card, style: .continuous)

    /// Canonical card shape for any corner radius; prefer this over building
    /// `RoundedRectangle` inline so corner style stays uniform.
    public static func shape(cornerRadius: CGFloat = Corners.card) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    public struct CardPlaceholderStyle: Sendable {
        public let color: Color
        public let icon: GameIcon

        public static let hero = Self(color: Colors.placeholderHero, icon: .system("person.fill"))
        public static let companion = Self(color: Colors.placeholderCompanion, icon: .system("pawprint.fill"))
        public static let enemy = Self(color: Colors.placeholderEnemy, icon: .system("shield.slash.fill"))
        public static let item = Self(color: Colors.placeholderItem, icon: .system("shippingbox.fill"))
        public static let ability = Self(color: Colors.placeholderAbility, icon: .system("wand.and.stars"))
    }
}
