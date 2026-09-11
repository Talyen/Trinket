import Foundation
import Testing
import UIKit
@testable import TrinketDesignSystem

struct DesignAssetCatalogTests {
    @Test func `bundled lucide assets resolve`() throws {
        struct Provenance: Decodable {
            let icons: [String: String]
        }

        let url = try #require(Bundle.module.url(forResource: "LucideProvenance", withExtension: "json"))
        let provenance = try JSONDecoder().decode(Provenance.self, from: Data(contentsOf: url))
        #expect(!provenance.icons.isEmpty)
        for name in provenance.icons.keys {
            let image = try #require(UIImage(named: "lucide-\(name)", in: .module, compatibleWith: nil))
            #expect(image.size.width > 0 && image.size.height > 0, "Empty Lucide asset: \(name)")
        }
    }

    @Test(arguments: DesignAssetColors.allCatalogAssetNames)
    func `catalog color resolves in dark and light modes`(assetName: String) throws {
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)

        // UIStyleCheck: allow - test resolves authored asset components, not semantic Color roles.
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
