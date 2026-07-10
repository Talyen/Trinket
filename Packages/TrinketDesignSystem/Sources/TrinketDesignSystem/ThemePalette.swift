import SwiftUI

struct ThemePalette {
    let appBackground: Color
    let secondaryBackground: Color
    let elevatedBackground: Color
    let panelSurface: Color
    let subtleStroke: Color
    let accent: Color
    let shadow: ShadowStyle

    static let apple = ThemePalette(
        appBackground: Color(.systemBackground),
        secondaryBackground: Color(.secondarySystemBackground),
        elevatedBackground: Color(.tertiarySystemBackground),
        panelSurface: Color(.secondarySystemGroupedBackground),
        subtleStroke: Color(.separator),
        accent: Color.accentColor,
        shadow: .elevated
    )
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    static let none = ShadowStyle(color: .clear, radius: 0, y: 0)
    static let subtle = ShadowStyle(color: .black.opacity(0.08), radius: 4, y: 2)
    static let elevated = ShadowStyle(color: .black.opacity(0.18), radius: 12, y: 5)
}
