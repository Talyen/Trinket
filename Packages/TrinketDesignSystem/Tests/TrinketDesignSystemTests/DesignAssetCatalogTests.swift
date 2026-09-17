import Foundation
import Testing
import UIKit
@testable import TrinketDesignSystem

struct DesignAssetCatalogTests {
    @Test func `icon identifiers resolve to available system symbols`() throws {
        #expect(GameIcon(id: "sf:leaf.fill") == GameIcon(id: "leaf.fill"))
        #expect(GameIcon(id: "sf:leaf.fill").id == "sf:leaf.fill")
        _ = try #require(UIImage(systemName: GameIcon(id: "sf:leaf.fill").symbolName))
    }

    @Test func `catalog asset list matches colorsets on disk`() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let catalogDirectory = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TrinketDesignSystem/Resources/DesignColors.xcassets", isDirectory: true)
        let contents = try #require(
            try? FileManager.default.contentsOfDirectory(atPath: catalogDirectory.path),
            "DesignColors.xcassets missing at \(catalogDirectory.path)",
        )
        let onDisk = Set(contents.filter { $0.hasSuffix(".colorset") }.map { String($0.dropLast(".colorset".count)) })
        try #expect(!onDisk.isEmpty, "No colorsets found at \(catalogDirectory.path)")
        let declared = Set(DesignAssetColors.allCatalogAssetNames)
        #expect(
            declared == onDisk,
            "Catalog drift — undeclared: \(onDisk.subtracting(declared).sorted()), orphaned: \(declared.subtracting(onDisk).sorted())",
        )
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
