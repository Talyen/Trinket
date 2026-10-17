import TrinketCore
import TrinketFeatureSupport
import XCTest

final class HomesteadControlsUITests: TrinketUITestCase {
    func testDisplayedUpgradeCostAndTierSurviveRelaunch() throws {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        try verifyWheatFieldUpgrade()
    }
}

extension TrinketUITestCase {
    func verifyWheatFieldUpgrade(audit: Bool = false) throws {
        homestead.assertLoaded()
        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        tapWhenReady(any(AccessibilityID.Homestead.node(title: "Wheat Field")))
        homestead.assertNodeDetail(named: "Wheat Field")
        var before: [HomesteadResource: Int] = [:]
        if !audit {
            tapButton(AccessibilityID.Homestead.walletButton)
            before = try homesteadBalances()
            tapButton(AccessibilityID.Homestead.closeSheetButton)
        }
        tapButton(AccessibilityID.Homestead.improveButton)
        assertExists(AccessibilityID.Homestead.upgradeSheet)
        var costs: [HomesteadResource: Int] = [:]
        if !audit {
            let identifiers = Set(HomesteadResource.allCases.map(AccessibilityID.Homestead.resourceCost))
            let displayed = try integers(in: any(AccessibilityID.Homestead.upgradeSheet), identifiers: identifiers)
            costs = Dictionary(uniqueKeysWithValues: HomesteadResource.allCases.compactMap { resource in
                displayed[AccessibilityID.Homestead.resourceCost(resource)].map { (resource, $0) }
            })
            XCTAssertFalse(costs.isEmpty, "Upgrade must display its actual cost")
        }
        if audit {
            try auditProductAccessibility(screen: "homestead-upgrade")
            retainScreenshot(named: "reachable-upgrade-controls")
        } else {
            attachSuccessScreenshot(named: "reachable-upgrade-controls")
        }
        tapButton(AccessibilityID.Homestead.upgradeButton)
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        assertExists(AccessibilityID.Homestead.progress(tier: 2))
        if audit {
            return
        }
        tapButton(AccessibilityID.Homestead.walletButton)
        let after = try homesteadBalances()
        for (resource, amount) in before {
            XCTAssertEqual(after[resource], amount - costs[resource, default: 0], "Displayed debit: \(resource)")
        }
        relaunchApp(arguments: ["-selectedTab", "homestead"])
        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        tapWhenReady(any(AccessibilityID.Homestead.node(title: "Wheat Field")))
        assertExists(AccessibilityID.Homestead.progress(tier: 2))
        tapButton(AccessibilityID.Homestead.walletButton)
        XCTAssertEqual(try homesteadBalances(), after)
        tapButton(AccessibilityID.Homestead.closeSheetButton)
    }

    private func homesteadBalances() throws -> [HomesteadResource: Int] {
        let wallet = any(AccessibilityID.Homestead.resourceWallet)
        assertExists(wallet)
        let identifiers = Set(HomesteadResource.allCases.map(AccessibilityID.Homestead.resourceBalance))
        var displayed: [String: Int] = [:]
        waitUntil("Wallet must expose every resource balance") {
            displayed = (try? self.integers(in: wallet, identifiers: identifiers)) ?? [:]
            return identifiers.isSubset(of: displayed.keys)
        }
        return try Dictionary(uniqueKeysWithValues: HomesteadResource.allCases.map { resource in
            try (resource, XCTUnwrap(displayed[AccessibilityID.Homestead.resourceBalance(resource)], "Missing balance: \(resource)"))
        })
    }
}
