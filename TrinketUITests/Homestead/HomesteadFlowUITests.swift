import XCTest

final class HomesteadFlowUITests: TrinketUITestCase {
    func testLockedProjectsRemainVisibleButDoNotOpenDetail() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))

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
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))

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
