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
        assertExistsAfterScroll(AccessibilityID.Homestead.category("Farming"))
        assertExistsAfterScroll(AccessibilityID.Homestead.node(title: "Wheat Field"))

        assertExistsAfterScroll(AccessibilityID.Homestead.category("Crafting"))
        assertExistsAfterScroll(AccessibilityID.Homestead.node(title: "Alchemy Lab"))
        assertExistsAfterScroll(AccessibilityID.Homestead.category("Research"))
    }

    func testLockedProjectsRemainVisibleButDoNotOpenDetail() {
        homestead.assertLoaded()
        let pastureID = AccessibilityID.Homestead.node(title: "Pasture")
        let pasture = app.descendants(matching: .any)[pastureID]
        scrollUntilVisible(pasture, swipingUp: true)
        assertExists(pastureID)
        XCTAssertFalse(
            app.buttons[pastureID].exists,
            "Locked projects should not be tappable navigation rows"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[AccessibilityID.Homestead.nodeDetail(title: "Pasture")].exists,
            "Locked projects should not open a detail destination"
        )
    }

    func testWheatFieldDetailRetainsTabBarAndNativeBackNavigation() {
        homestead.assertLoaded()
        homestead.openNode(named: "Wheat Field")

        homestead.assertNodeDetail(named: "Wheat Field")
        assertExists(AccessibilityID.Homestead.tierPath)
        let tabButton = app.tabBars.buttons["Homestead"]
        XCTAssertTrue(tabButton.exists, "Tab bar should remain present on detail")
        XCTAssertTrue(tabButton.isHittable, "Tab bar should remain hittable above detail content")
        XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).exists, "Native back affordance should be present")

        goBack()
        homestead.assertLoaded()
    }
}
