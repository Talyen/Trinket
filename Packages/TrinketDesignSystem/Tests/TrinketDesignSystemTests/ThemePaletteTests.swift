import Foundation
import SwiftUI
import Testing
import UIKit
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

    @Test func semanticForegroundsMeetContrastInDarkEnvironment() throws {
        // Resolve via UIKit asset lookup (dark traits) instead of SwiftUI
        // `Color.resolve`, which pays a multi-second host cold start in this package.
        let canvas = try darkResolvedSRGB("ThemeCanvas")
        let semanticForegroundNames = [
            "ThemeAntiqueGold",
            "ThemeHighlightGold",
            "ThemePressedGold",
            "ThemeSuccess",
            "ThemeWarning",
            "ThemeDestructive",
            "ThemeInformational",
            "ThemeArcane",
            "ThemeHealth",
            "ThemeHealthRestore",
        ]

        var accent: (red: Double, green: Double, blue: Double)?
        for name in semanticForegroundNames {
            let color = try darkResolvedSRGB(name)
            if name == "ThemeAntiqueGold" {
                accent = color
            }
            #expect(contrastRatio(color, canvas) >= 4.5)
        }
        let resolvedAccent = try #require(accent)
        #expect(contrastRatio(canvas, resolvedAccent) >= 4.5)
    }
}

private func darkResolvedSRGB(_ name: String) throws -> (red: Double, green: Double, blue: Double) {
    // UIStyleCheck: allow - contrast math needs authored asset components, not semantic Color roles.
    let traits = UITraitCollection(userInterfaceStyle: .dark)
    let color = try #require(UIColor(named: name, in: .module, compatibleWith: traits))
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
        throw CocoaError(.coderInvalidValue)
    }
    return (Double(red), Double(green), Double(blue))
}

private func contrastRatio(
    _ lhs: (red: Double, green: Double, blue: Double),
    _ rhs: (red: Double, green: Double, blue: Double)
) -> Double {
    let lighter = max(relativeLuminance(lhs), relativeLuminance(rhs))
    let darker = min(relativeLuminance(lhs), relativeLuminance(rhs))
    return (lighter + 0.05) / (darker + 0.05)
}

private func relativeLuminance(_ color: (red: Double, green: Double, blue: Double)) -> Double {
    func linearize(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }

    return 0.2126 * linearize(color.red)
        + 0.7152 * linearize(color.green)
        + 0.0722 * linearize(color.blue)
}
