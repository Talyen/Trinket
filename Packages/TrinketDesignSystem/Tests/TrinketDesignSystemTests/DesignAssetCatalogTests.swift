import Foundation
import Testing
import UIKit
@testable import TrinketDesignSystem

struct DesignAssetCatalogTests {
    @Test(arguments: DesignAssetColors.allCatalogAssetNames)
    func `catalog color resolves in dark and light modes`(assetName: String) throws {
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)

        let darkColor = try #require(UIColor(named: assetName, in: .module, compatibleWith: darkTraits))
        let lightColor = try #require(UIColor(named: assetName, in: .module, compatibleWith: lightTraits))

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        #expect(darkColor.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(a > 0)

        #expect(lightColor.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(a > 0)
    }
}
