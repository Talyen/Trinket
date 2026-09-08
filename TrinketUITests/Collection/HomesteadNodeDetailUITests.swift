import TrinketFeatureSupport
import XCTest

final class HomesteadNodeDetailUITests: TrinketUITestCase {
    func testHomesteadNodeDetailJourney() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        homestead.assertLoaded()

        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        assertExists(AccessibilityID.Homestead.gallery)
        tapButton(AccessibilityID.Homestead.node(title: "Wheat Field"))
        homestead.assertNodeDetail(named: "Wheat Field")
        assertExists(AccessibilityID.Homestead.currentEffects)
        XCTAssertFalse(app.tabBars.buttons[AccessibilityID.Tab.homestead].isHittable)
        tapButton(AccessibilityID.Homestead.improveButton)
        assertExists(AccessibilityID.Homestead.upgradeSheet)
        assertExists(AccessibilityID.Homestead.upgradeEffects)
        assertExists(AccessibilityID.Homestead.upgradeCost)
        tapButton(AccessibilityID.Homestead.upgradeButton)
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        assertExists(AccessibilityID.Homestead.progress(tier: 2))
        assertExists(AccessibilityID.Homestead.currentEffects)

        tapButton(AccessibilityID.Homestead.improveButton)
        XCTAssertFalse(button(AccessibilityID.Homestead.upgradeButton).isEnabled)
        any(AccessibilityID.Homestead.upgradeSheet).swipeDown()
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        tapButton(AccessibilityID.Homestead.backButton)
        XCTAssertTrue(app.tabBars.buttons[AccessibilityID.Tab.homestead].isHittable)
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
        tabBar.selectOptions()
        tabBar.selectHomestead()
        homestead.assertLoaded()
        assertDoesNotExist(AccessibilityID.Homestead.collectButton)
    }
}
