import SwiftUI
import Testing
import TrinketCore
import UIKit
@testable import TrinketDesignSystem

struct KeywordVisualStyleTests {
    @Test func `every keyword resolves a visual style with an available symbol`() throws {
        for keyword in Keyword.allCases {
            let style = keyword.visualStyle
            _ = try #require(
                UIImage(systemName: style.icon.symbolName),
                "Missing symbol for \(keyword): \(style.icon.symbolName)",
            )
        }
        for style in [Keyword.VisualStyle.beneficialStatus, .negativeStatus] {
            _ = try #require(UIImage(systemName: style.icon.symbolName))
        }
    }

    @Test func `gold aliases accent and thorns aliases physical`() {
        #expect(matches(Keyword.gold.visualStyle.color, asset: "ThemeAntiqueGold"))
        #expect(matches(Keyword.thorns.visualStyle.color, asset: "KeywordPhysical"))
        #expect(matches(Keyword.burn.visualStyle.secondaryColor, asset: "KeywordPhysical"))
        #expect(matches(Keyword.health.visualStyle.secondaryColor, asset: "ThemeHealth"))
    }

    @Test func `every homestead resource resolves its documented tint`() {
        let expectedAsset: [HomesteadResource: String] = [
            .wood: "ResourceWood",
            .stone: "ResourceStone",
            .iron: "ResourceIron",
            .food: "ResourceFood",
            .herbs: "ResourceHerbs",
            .hide: "ResourceHide",
            .gems: "ResourceGems",
        ]
        for resource in HomesteadResource.allCases {
            if let asset = expectedAsset[resource] {
                #expect(matches(resource.tint, asset: asset), "Tint drift for \(resource)")
            } else {
                #expect(matches(resource.tint, asset: "ThemeAntiqueGold"), "Gold tint must stay accent")
            }
            // Icons live in TrinketFeatureSupport and are pinned by GameIconCatalogTests.
        }
    }

    @Test func `increase prefix applies after compact formatting`() {
        #expect(TrinketWalletFormatting.displayString(for: 50, showsIncreasePrefix: true) == "+50")
        #expect(TrinketWalletFormatting.displayString(for: 50, showsIncreasePrefix: false) == "50")
        #expect(
            TrinketWalletFormatting.displayString(for: 100000, showsIncreasePrefix: true)
                == "+\(100000.formatted(.number.notation(.compactName)))",
        )
    }
}

private func matches(_ color: Color, asset name: String) -> Bool {
    // Resolve both sides in the same dark environment so dynamic asset
    // appearances compare instead of snapshotting ambient traits.
    var environment = EnvironmentValues()
    environment.colorScheme = .dark
    let lhs = color.resolve(in: environment)
    // UIStyleCheck: allow - test resolves authored asset components, not semantic Color roles.
    let rhs = Color(name, bundle: .module).resolve(in: environment)
    return abs(lhs.red - rhs.red) < 0.005 && abs(lhs.green - rhs.green) < 0.005 && abs(lhs.blue - rhs.blue) < 0.005
}
