import CoreGraphics
import SwiftUI
import Testing
import TrinketCore
import UIKit
@testable import TrinketDesignSystem

struct KeywordPlasmaTests {
    @Test func `empty keywords fall back to accent`() throws {
        let resolved = KeywordPlasmaBackground.colors(for: [])
        #expect(try matches(resolved.primary, asset: "ThemeAntiqueGold"))
        #expect(try matches(resolved.secondary, asset: "ThemeAntiqueGold"))
    }

    @Test func `single keyword derives secondary from its visual style`() throws {
        let resolved = KeywordPlasmaBackground.colors(for: [.burn])
        #expect(try matches(resolved.primary, asset: "KeywordBurn"))
        #expect(try matches(resolved.secondary, asset: "KeywordPhysical"))
    }

    @Test func `keyword list is limited to the first two`() throws {
        let resolved = KeywordPlasmaBackground.colors(for: [.burn, .stun, .block])
        #expect(try matches(resolved.primary, asset: "KeywordBurn"))
        #expect(try matches(resolved.secondary, asset: "KeywordStun"))
    }

    @Test func `center maps the focal point into points`() {
        let source = KeywordPlasmaBackground.Source(keywords: [.burn], focalPoint: UnitPoint(x: 0.25, y: 0.5))
        let center = KeywordPlasmaBackground.center(for: source, in: CGSize(width: 200, height: 100))
        #expect(center.x == 50)
        #expect(center.y == 50)
    }
}

private func matches(_ color: Color, asset name: String, style: UIUserInterfaceStyle = .dark) throws -> Bool {
    // UIStyleCheck: allow - test compares authored asset components, not semantic Color roles.
    let lhs = try srgb(UIColor(color), style: style)
    let rhs = try srgb(named: name, style: style)
    return abs(lhs.0 - rhs.0) < 0.005 && abs(lhs.1 - rhs.1) < 0.005 && abs(lhs.2 - rhs.2) < 0.005
}

private func srgb(named name: String, style: UIUserInterfaceStyle) throws -> (Double, Double, Double) {
    let traits = UITraitCollection(userInterfaceStyle: style)
    // UIStyleCheck: allow - test resolves authored asset components, not semantic Color roles.
    let color = try #require(UIColor(named: name, in: .module, compatibleWith: traits))
    return try srgb(color, style: style)
}

private func srgb(_ color: UIColor, style: UIUserInterfaceStyle) throws -> (Double, Double, Double) {
    let traits = UITraitCollection(userInterfaceStyle: style)
    let resolved = color.resolvedColor(with: traits)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
        throw CocoaError(.coderInvalidValue)
    }
    return (Double(red), Double(green), Double(blue))
}
