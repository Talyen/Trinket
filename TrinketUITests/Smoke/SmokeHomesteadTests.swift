import XCTest

final class SmokeHomesteadTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("homestead")
    }

    func testHomesteadTabLoads() {
        homestead.assertLoaded()
    }

    func testHomesteadOverviewShowsWalletCategoriesAndRepresentativeRows() {
        homestead.assertLoaded()
        assertExists(AccessibilityID.Homestead.resourceWallet)
        assertExists(AccessibilityID.Homestead.category("Farming"))
        assertExists(AccessibilityID.Homestead.node(title: "Wheat Field"))

        assertExistsAfterScroll(AccessibilityID.Homestead.category("Crafting"))
        assertExistsAfterScroll(AccessibilityID.Homestead.node(title: "Alchemy Lab"))
        assertExistsAfterScroll(AccessibilityID.Homestead.category("Research"))
    }

    func testLockedProjectPushesToPrerequisiteDetail() {
        homestead.assertLoaded()
        let pasture = app.descendants(matching: .any)[AccessibilityID.Homestead.node(title: "Pasture")]
        scrollUntilVisible(pasture, swipingUp: true)
        tapWhenReady(pasture)

        homestead.assertNodeDetail(named: "Pasture")
        assertExists(AccessibilityID.Homestead.prerequisiteCallout)
        assertExists(AccessibilityID.Homestead.tierPath)
        assertExists("Build Pasture Button")
    }

    func testWheatFieldDetailRetainsTabBarAndNativeBackNavigation() {
        homestead.assertLoaded()
        homestead.openNode(named: "Wheat Field")

        homestead.assertNodeDetail(named: "Wheat Field")
        assertExists(AccessibilityID.Homestead.tierPath)
        let action = app.buttons["Upgrade Wheat Field Button"]
        XCTAssertTrue(action.waitForExistence(timeout: Self.defaultTimeout), "Upgrade action should exist")
        let tabButton = app.tabBars.buttons["Homestead"]
        XCTAssertTrue(tabButton.exists, "Tab bar should remain present on detail")
        XCTAssertTrue(tabButton.isHittable, "Tab bar should remain hittable above detail content")
        XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).exists, "Native back affordance should be present")

        XCTAssertLessThanOrEqual(action.frame.maxY, app.tabBars.element.frame.minY + 1, "Footer action must not overlap the tab bar")

        goBack()
        homestead.assertLoaded()
    }
}
