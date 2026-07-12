import SwiftUI
import Testing
@testable import TrinketDesignSystem

struct ThemePaletteTests {
    @Test func themePaletteUsesBundledSemanticColors() throws {
        let palette = ThemePalette.trinket
        try #expect(palette.appBackground != .clear)
        try #expect(palette.secondaryBackground != .clear)
        try #expect(palette.elevatedBackground != .clear)
        try #expect(palette.panelSurface != .clear)
        try #expect(palette.subtleStroke != .clear)
        try #expect(palette.accent != .clear)
        try #expect(palette.accentEmphasized != .clear)
        try #expect(palette.accentPressed != .clear)
        try #expect(palette.success != .clear)
        try #expect(palette.warning != .clear)
        try #expect(palette.destructive != .clear)
        try #expect(palette.informational != .clear)
        try #expect(palette.arcane != .clear)
        try #expect(palette.health != .clear)
        try #expect(palette.healthRestore != .clear)
        try #expect(palette.overlayInk != .clear)
        try #expect(palette.overlayPaper != .clear)
        try #expect(palette.heroScrim != .clear)
    }

    @Test func semanticForegroundsMeetContrastInDarkEnvironment() {
        var environment = EnvironmentValues()
        environment.colorScheme = .dark

        let palette = ThemePalette.trinket
        let canvas = palette.appBackground.resolve(in: environment)
        let semanticForegrounds = [
            palette.accent,
            palette.accentEmphasized,
            palette.accentPressed,
            palette.success,
            palette.warning,
            palette.destructive,
            palette.informational,
            palette.arcane,
            palette.health,
            palette.healthRestore
        ]

        for color in semanticForegrounds {
            #expect(contrastRatio(color.resolve(in: environment), canvas) >= 4.5)
        }
        #expect(contrastRatio(canvas, palette.accent.resolve(in: environment)) >= 4.5)
    }

    @Test func surfaceLuminanceIncreasesWithElevation() {
        var environment = EnvironmentValues()
        environment.colorScheme = .dark
        let palette = ThemePalette.trinket
        let levels = [
            palette.appBackground,
            palette.secondaryBackground,
            palette.panelSurface,
            palette.elevatedBackground
        ].map { relativeLuminance($0.resolve(in: environment)) }

        #expect(levels[0] < levels[1])
        #expect(levels[1] < levels[2])
        #expect(levels[2] < levels[3])
    }

    @Test func shadowStylesHaveExpectedRadii() throws {
        try #expect(ShadowStyle.none.radius == 0)
        try #expect(ShadowStyle.subtle.radius > 0)
        try #expect(ShadowStyle.elevated.radius > ShadowStyle.subtle.radius)
    }
}

private func contrastRatio(_ lhs: Color.Resolved, _ rhs: Color.Resolved) -> Double {
    let lighter = max(relativeLuminance(lhs), relativeLuminance(rhs))
    let darker = min(relativeLuminance(lhs), relativeLuminance(rhs))
    return (lighter + 0.05) / (darker + 0.05)
}

private func relativeLuminance(_ color: Color.Resolved) -> Double {
    func linearize(_ component: Float) -> Double {
        let value = Double(component)
        return value <= 0.04045
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }

    return 0.2126 * linearize(color.red)
        + 0.7152 * linearize(color.green)
        + 0.0722 * linearize(color.blue)
}
