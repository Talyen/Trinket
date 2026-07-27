import SwiftUI

struct ThemePalette {
    let appBackground: Color
    let secondaryBackground: Color
    let elevatedBackground: Color
    let panelSurface: Color
    let subtleStroke: Color
    let accent: Color
    let accentEmphasized: Color
    let accentPressed: Color
    let success: Color
    let warning: Color
    let destructive: Color
    let informational: Color
    let arcane: Color
    let health: Color
    let healthRestore: Color
    let overlayInk: Color
    let overlayPaper: Color
    let heroScrim: Color
    let shadow: ShadowStyle

    static let trinket = Self(
        appBackground: DesignAssetColors.named("ThemeCanvas"),
        secondaryBackground: DesignAssetColors.named("ThemeSurface"),
        elevatedBackground: DesignAssetColors.named("ThemeElevated"),
        panelSurface: DesignAssetColors.named("ThemePanel"),
        subtleStroke: DesignAssetColors.named("ThemeSubtleStroke"),
        accent: DesignAssetColors.named("ThemeAntiqueGold"),
        accentEmphasized: DesignAssetColors.named("ThemeHighlightGold"),
        accentPressed: DesignAssetColors.named("ThemePressedGold"),
        success: DesignAssetColors.named("ThemeSuccess"),
        warning: DesignAssetColors.named("ThemeWarning"),
        destructive: DesignAssetColors.named("ThemeDestructive"),
        informational: DesignAssetColors.named("ThemeInformational"),
        arcane: DesignAssetColors.named("ThemeArcane"),
        health: DesignAssetColors.named("ThemeHealth"),
        healthRestore: DesignAssetColors.named("ThemeHealthRestore"),
        overlayInk: DesignAssetColors.named("ThemeOverlayInk"),
        overlayPaper: DesignAssetColors.named("ThemeOverlayPaper"),
        heroScrim: DesignAssetColors.named("ThemeHeroScrim"),
        shadow: .elevated
    )
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    static let none = Self(color: .clear, radius: 0, y: 0)
    static let subtle = Self(
        color: DesignAssetColors.named("ThemeOverlayInk").opacity(0.08),
        radius: 4,
        y: 2
    )
    static let elevated = Self(
        color: DesignAssetColors.named("ThemeOverlayInk").opacity(0.18),
        radius: 12,
        y: 5
    )
}
