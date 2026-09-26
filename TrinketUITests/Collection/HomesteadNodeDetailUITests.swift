import TrinketFeatureSupport
import XCTest

final class HomesteadNodeDetailUITests: TrinketUITestCase {
    func testBlacksmithForgeAndInspectJourney() {
        launchApp(arguments: TestLaunchArg.allForTab("options"))
        options.assertLoaded()
        scrollUntilVisible(button(AccessibilityID.Options.unlockAllButton), swipingUp: true, requireHittable: true)
        tapButton(AccessibilityID.Options.unlockAllButton)
        tabBar.selectHomestead()
        homestead.assertLoaded()
        scrollUntilVisible(button(AccessibilityID.Homestead.category("Crafting")), swipingUp: true, requireHittable: true)
        tapButton(AccessibilityID.Homestead.category("Crafting"))
        tapButton(AccessibilityID.Homestead.node(title: "Blacksmith"))
        assertExists(AccessibilityID.Homestead.currentEffects)
        tapButton(AccessibilityID.Homestead.craftButton)
        assertExists(AccessibilityID.Homestead.forgeGrid)
        dragForgeSheet(to: 0.12)
        tapButton(AccessibilityID.Homestead.forgeRecipe("blacksmith-dagger"))
        XCTAssertTrue(button(AccessibilityID.Homestead.forgeButton).exists)
        assertExists(AccessibilityID.Homestead.forgePreview)
        XCTAssertFalse(button(AccessibilityID.Homestead.improveButton).isHittable)
        tapButton(AccessibilityID.Homestead.forgeButton)
        assertExists(AccessibilityID.Homestead.forgeDetail)
        assertExists(AccessibilityID.Homestead.forgeAdded)
        XCTAssertFalse(button(AccessibilityID.Homestead.forgeButton).exists)
        XCTAssertFalse(button(AccessibilityID.Homestead.forgeDone).exists)
        dragForgeSheet(to: 0.98)
        assertDoesNotExist(AccessibilityID.Homestead.forgeGrid)
        assertExists(AccessibilityID.Homestead.currentEffects)
    }

    private func dragForgeSheet(to verticalPosition: CGFloat) {
        let grabber = button("Sheet Grabber")
        XCTAssertTrue(grabber.trinketWaitForExistence(timeout: 5))
        grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: verticalPosition)))
    }

    func testBuildBlacksmithWithoutOtherCraftingBuildings() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        homestead.assertLoaded()
        scrollUntilVisible(button(AccessibilityID.Homestead.category("Crafting")), swipingUp: true, requireHittable: true)
        tapButton(AccessibilityID.Homestead.category("Crafting"))
        tapButton(AccessibilityID.Homestead.node(title: "Blacksmith"))
        homestead.assertNodeDetail(named: "Blacksmith")
        assertExists(AccessibilityID.Homestead.progress(tier: 0))
        XCTAssertFalse(button(AccessibilityID.Homestead.craftButton).exists)
        tapButton(AccessibilityID.Homestead.improveButton)
        assertExists(AccessibilityID.Homestead.upgradeSheet)
        XCTAssertTrue(button(AccessibilityID.Homestead.upgradeButton).isEnabled)
        tapButton(AccessibilityID.Homestead.upgradeButton)
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        assertExists(AccessibilityID.Homestead.progress(tier: 1))
        assertExists(AccessibilityID.Homestead.craftButton)
        tapButton(AccessibilityID.Homestead.backButton)
        tapButton(AccessibilityID.Homestead.node(title: "Blacksmith"))
        homestead.assertNodeDetail(named: "Blacksmith")
        assertExists(AccessibilityID.Homestead.progress(tier: 1))
    }

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
