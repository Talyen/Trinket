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

    func testCrystalGardenShowsAndUpgradesBothMaterials() {
        launchApp(arguments: TestLaunchArg.allForTab("options"))
        options.assertLoaded()
        scrollUntilVisible(button(AccessibilityID.Options.unlockAllButton), swipingUp: true, requireHittable: true)
        tapButton(AccessibilityID.Options.unlockAllButton)
        tabBar.selectHomestead()
        homestead.assertLoaded()
        scrollUntilVisible(button(AccessibilityID.Homestead.category("Alchemy")), swipingUp: true, requireHittable: true)
        tapButton(AccessibilityID.Homestead.category("Alchemy"))
        tapButton(AccessibilityID.Homestead.node(title: "Crystal Garden"))
        homestead.assertNodeDetail(named: "Crystal Garden")
        assertExists(AccessibilityID.Homestead.currentEffects)
        let effects = any(AccessibilityID.Homestead.currentEffects)
        var labels = effects.label
        for element in effects.descendants(matching: .any).allElementsBoundByIndex {
            labels += " " + element.label
        }
        XCTAssertTrue(labels.contains("Critical damage"))
        XCTAssertTrue(labels.contains("Gems"))
        XCTAssertTrue(labels.contains("Stone"))
        attachSuccessScreenshot(named: "Crystal Garden — two material outputs")
        tapButton(AccessibilityID.Homestead.improveButton)
        assertExists(AccessibilityID.Homestead.upgradeSheet)
        attachSuccessScreenshot(named: "Crystal Garden — fourth-tier offer")
        tapButton(AccessibilityID.Homestead.upgradeButton)
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        assertExists(AccessibilityID.Homestead.progress(tier: 4))
        XCTAssertFalse(button(AccessibilityID.Homestead.improveButton).exists)
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
