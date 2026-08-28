import Foundation
import SwiftUI
import Testing
import UIKit
@testable import TrinketDesignSystem

struct SemanticColorContrastTests {
    private static let semanticForegroundNames = [
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

    @Test(arguments: semanticForegroundNames)
    func semanticForegroundMeetsContrastInDarkEnvironment(colorName: String) throws {
        let canvas = try darkResolvedSRGB("ThemeCanvas")
        let color = try darkResolvedSRGB(colorName)
        #expect(contrastRatio(color, canvas) >= 4.5)
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
