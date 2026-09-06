import TrinketFeatureSupport
import XCTest

final class HomesteadNodeDetailUITests: TrinketUITestCase {
    func testHomesteadNodeDetailJourney() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        homestead.assertLoaded()

        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        tapButton(AccessibilityID.Homestead.node(title: "Wheat Field"))
        homestead.assertNodeDetail(named: "Wheat Field")
    }

    func testCollectedMaterialsStayCollectedAfterReturning() {
        launchApp(arguments: TestLaunchArg.allForTab("options"))
        options.assertLoaded()
        let unlock = button(AccessibilityID.Options.unlockAllButton)
        scrollUntilVisible(unlock, swipingUp: true, requireHittable: true)
        tapButton(AccessibilityID.Options.unlockAllButton)
        tabBar.selectHomestead()
        homestead.assertLoaded()
        tapButton(AccessibilityID.Homestead.collectButton)
        assertDoesNotExist(AccessibilityID.Homestead.collectButton)
        XCTAssertEqual(app.staticTexts.matching(identifier: "910").count, 5)
        tabBar.selectOptions()
        tabBar.selectHomestead()
        homestead.assertLoaded()
        assertDoesNotExist(AccessibilityID.Homestead.collectButton)
    }
}
