import SwiftUI

public struct ThemePalette: Sendable {
    public let appBackground: Color
    public let secondaryBackground: Color
    public let elevatedBackground: Color
    public let panelSurface: Color
    public let subtleStroke: Color
    public let accent: Color
    public let shadow: ShadowStyle

    public init(
        appBackground: Color,
        secondaryBackground: Color,
        elevatedBackground: Color,
        panelSurface: Color,
        subtleStroke: Color,
        accent: Color,
        shadow: ShadowStyle
    ) {
        self.appBackground = appBackground
        self.secondaryBackground = secondaryBackground
        self.elevatedBackground = elevatedBackground
        self.panelSurface = panelSurface
        self.subtleStroke = subtleStroke
        self.accent = accent
        self.shadow = shadow
    }

    public static let apple = ThemePalette(
        appBackground: Color(.systemBackground),
        secondaryBackground: Color(.secondarySystemBackground),
        elevatedBackground: Color(.tertiarySystemBackground),
        panelSurface: Color(.secondarySystemBackground),
        subtleStroke: Color(.separator),
        accent: Color.accentColor,
        shadow: .elevated
    )
}

public struct ShadowStyle: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let y: CGFloat

    public static let none = ShadowStyle(color: .clear, radius: 0, y: 0)
    public static let subtle = ShadowStyle(color: .black.opacity(0.08), radius: 4, y: 2)
    public static let elevated = ShadowStyle(color: .black.opacity(0.18), radius: 12, y: 5)
}
