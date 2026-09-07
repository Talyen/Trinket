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

        app.terminate()
        app.launchArguments.removeAll { $0 == TestLaunchArg.resetState || $0 == TestLaunchArg.seedTestProgress }
        app.launch()
        homestead.assertLoaded()
        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        tapButton(AccessibilityID.Homestead.node(title: "Wheat Field"))
        assertExists(AccessibilityID.Homestead.progress(tier: 2))
        assertExists(AccessibilityID.Homestead.currentEffects)
        tapButton(AccessibilityID.Homestead.improveButton)
        XCTAssertFalse(button(AccessibilityID.Homestead.upgradeButton).isEnabled)
        any(AccessibilityID.Homestead.upgradeSheet).swipeDown()
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        tapButton(AccessibilityID.Homestead.backButton)
        XCTAssertTrue(app.tabBars.buttons[AccessibilityID.Tab.homestead].isHittable)
    }

    func testFinalUpgradeLeavesBenefitsInspectable() {
        launchApp(arguments: TestLaunchArg.allForTab("options"))
        options.assertLoaded()
        let unlock = button(AccessibilityID.Options.unlockAllButton)
        scrollUntilVisible(unlock, swipingUp: true, requireHittable: true)
        tapButton(AccessibilityID.Options.unlockAllButton)
        tabBar.selectHomestead()
        homestead.assertLoaded()
        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        tapButton(AccessibilityID.Homestead.node(title: "Wheat Field"))
        tapButton(AccessibilityID.Homestead.improveButton)
        tapButton(AccessibilityID.Homestead.upgradeButton)
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        assertDoesNotExist(AccessibilityID.Homestead.improveButton)
        assertExists(AccessibilityID.Homestead.progress(tier: 4))
        assertExists(AccessibilityID.Homestead.currentEffects)
    }

    func testLockedProjectShowsBuildBenefitsAndCosts() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        homestead.assertLoaded()
        let category = button(AccessibilityID.Homestead.category("Alchemy"))
        scrollUntilVisible(category, swipingUp: true, requireHittable: true)
        tapButton(AccessibilityID.Homestead.category("Alchemy"))
        tapButton(AccessibilityID.Homestead.node(title: "Alchemy Lab"))
        assertExists(AccessibilityID.Homestead.currentEffects)
        assertExists(AccessibilityID.Homestead.progress(tier: 0))
        tapButton(AccessibilityID.Homestead.improveButton)
        assertExists(AccessibilityID.Homestead.upgradeEffects)
        assertExists(AccessibilityID.Homestead.upgradeCost)
        XCTAssertFalse(button(AccessibilityID.Homestead.upgradeButton).isEnabled)
        any(AccessibilityID.Homestead.upgradeSheet).swipeDown()
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        tapButton(AccessibilityID.Homestead.backButton)
        tapButton(AccessibilityID.Homestead.walletButton)
        assertExists(AccessibilityID.Homestead.resourceWallet)
        tapButton(AccessibilityID.Homestead.closeSheetButton)
        assertExists(AccessibilityID.Homestead.gallery)
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
