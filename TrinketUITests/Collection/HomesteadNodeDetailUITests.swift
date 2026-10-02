import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import XCTest

final class HomesteadNodeDetailUITests: TrinketUITestCase {
    func testHomesteadBuildingSpendsResourcesAndSurvivesRelaunch() throws {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        homestead.assertLoaded()
        var balances: [HomesteadResource: Int] = [:]
        for resource in HomesteadResource.allCases {
            balances[resource] = try integer(in: any(AccessibilityID.Homestead.resourceBalance(resource)))
        }
        openBlacksmith()
        assertExists(AccessibilityID.Homestead.progress(tier: 0))
        XCTAssertFalse(button(AccessibilityID.Homestead.craftButton).exists)
        tapButton(AccessibilityID.Homestead.improveButton)
        assertExists(AccessibilityID.Homestead.upgradeSheet)
        let cost = any(AccessibilityID.Homestead.upgradeCost)
        var spent: [HomesteadResource: Int] = [:]
        for resource in HomesteadResource.allCases {
            let amount = cost.descendants(matching: .any)[AccessibilityID.Homestead.resourceCost(resource)]
            if amount.exists {
                spent[resource] = try integer(in: amount)
            }
        }
        XCTAssertFalse(spent.isEmpty, "The build must advertise its resource cost")
        tapButton(AccessibilityID.Homestead.upgradeButton)
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        assertExists(AccessibilityID.Homestead.progress(tier: 1))
        assertExists(AccessibilityID.Homestead.craftButton)
        relaunchApp(arguments: ["-selectedTab", "homestead"])
        for (resource, quantity) in spent {
            XCTAssertEqual(
                try integer(in: any(AccessibilityID.Homestead.resourceBalance(resource))),
                try XCTUnwrap(balances[resource]) - quantity,
            )
        }
        openBlacksmith()
        assertExists(AccessibilityID.Homestead.progress(tier: 1))
        assertExists(AccessibilityID.Homestead.craftButton)
    }

    private func openBlacksmith() {
        assertExistsAfterScroll(AccessibilityID.Homestead.category("Crafting"), requireHittable: true)
        tapButton(AccessibilityID.Homestead.category("Crafting"))
        tapButton(AccessibilityID.Homestead.node(title: "Blacksmith"))
        homestead.assertNodeDetail(named: "Blacksmith")
    }
}
