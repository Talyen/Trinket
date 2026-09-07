import TrinketFeatureSupport
import XCTest

final class HomesteadNodeDetailUITests: TrinketUITestCase {
    func testHomesteadNodeDetailJourney() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        homestead.assertLoaded()

        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        tapButton(AccessibilityID.Homestead.node(title: "Wheat Field"))
        homestead.assertNodeDetail(named: "Wheat Field")
        XCTAssertFalse(app.tabBars.buttons[AccessibilityID.Tab.homestead].isHittable)
        tapButton(AccessibilityID.Homestead.improveButton)
        assertExists(AccessibilityID.Homestead.upgradeSheet)
        assertDoesNotExist(AccessibilityID.Homestead.allTiersButton)
        tapButton(AccessibilityID.Homestead.effectDisclosure)
        tapButton(AccessibilityID.Homestead.allTiersButton)
        assertExists(AccessibilityID.Homestead.tierHistory)
        tapButton(AccessibilityID.Homestead.closeSheetButton)
        tapButton(AccessibilityID.Homestead.improveButton)
        tapButton(AccessibilityID.Homestead.upgradeButton)
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        tapButton(AccessibilityID.Homestead.benefitsButton)
        assertExists(AccessibilityID.Homestead.tierNode(title: "Wheat Field", tier: 2))
        tapButton(AccessibilityID.Homestead.closeSheetButton)

        app.terminate()
        app.launchArguments.removeAll { $0 == TestLaunchArg.resetState || $0 == TestLaunchArg.seedTestProgress }
        app.launch()
        homestead.assertLoaded()
        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        tapButton(AccessibilityID.Homestead.node(title: "Wheat Field"))
        tapButton(AccessibilityID.Homestead.benefitsButton)
        assertExists(AccessibilityID.Homestead.tierNode(title: "Wheat Field", tier: 2))
        tapButton(AccessibilityID.Homestead.closeSheetButton)
        tapButton(AccessibilityID.Homestead.improveButton)
        XCTAssertFalse(button(AccessibilityID.Homestead.upgradeButton).isEnabled)
        tapButton(AccessibilityID.Homestead.closeSheetButton)
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
        tapButton(AccessibilityID.Homestead.benefitsButton)
        assertExists(AccessibilityID.Homestead.tierNode(title: "Wheat Field", tier: 4))
        tapButton(AccessibilityID.Homestead.allTiersButton)
        assertExists(AccessibilityID.Homestead.tierHistory)
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
