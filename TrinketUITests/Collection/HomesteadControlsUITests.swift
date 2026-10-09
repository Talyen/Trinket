import TrinketCore
import TrinketFeatureSupport
import XCTest

final class HomesteadControlsUITests: TrinketUITestCase {
    func testDisplayedUpgradeCostAndTierSurviveRelaunch() throws {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        try verifyWheatFieldUpgrade(relaunch: true)
    }
}

extension TrinketUITestCase {
    func verifyWheatFieldUpgrade(relaunch: Bool, audit: Bool = false) throws {
        homestead.assertLoaded()
        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        tapWhenReady(any(AccessibilityID.Homestead.node(title: "Wheat Field")))
        homestead.assertNodeDetail(named: "Wheat Field")
        tapButton(AccessibilityID.Homestead.walletButton)
        let before = try homesteadBalances()
        tapButton(AccessibilityID.Homestead.closeSheetButton)
        tapButton(AccessibilityID.Homestead.improveButton)
        assertExists(AccessibilityID.Homestead.upgradeSheet)
        var costs: [HomesteadResource: Int] = [:]
        for resource in HomesteadResource.allCases {
            let value = any(AccessibilityID.Homestead.resourceCost(resource))
            if value.exists {
                costs[resource] = try integer(in: value)
            }
        }
        XCTAssertFalse(costs.isEmpty, "Upgrade must display its actual cost")
        if audit {
            try auditProductAccessibility()
        }
        retainScreenshot(named: "reachable-upgrade-controls")
        tapButton(AccessibilityID.Homestead.upgradeButton)
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        assertExists(AccessibilityID.Homestead.progress(tier: 2))
        tapButton(AccessibilityID.Homestead.walletButton)
        let after = try homesteadBalances()
        for (resource, amount) in before {
            XCTAssertEqual(after[resource], amount - costs[resource, default: 0], "Displayed debit: \(resource)")
        }
        if relaunch {
            relaunchApp(arguments: ["-selectedTab", "homestead"])
            homestead.openFarmingCategoryAndRevealWheatFieldNode()
            tapWhenReady(any(AccessibilityID.Homestead.node(title: "Wheat Field")))
            assertExists(AccessibilityID.Homestead.progress(tier: 2))
            tapButton(AccessibilityID.Homestead.walletButton)
            XCTAssertEqual(try homesteadBalances(), after)
        }
        tapButton(AccessibilityID.Homestead.closeSheetButton)
    }

    private func homesteadBalances() throws -> [HomesteadResource: Int] {
        var amounts: [HomesteadResource: Int] = [:]
        for resource in HomesteadResource.allCases {
            let element = any(AccessibilityID.Homestead.resourceBalance(resource))
            assertExists(element)
            amounts[resource] = try integer(in: element)
        }
        return amounts
    }
}
