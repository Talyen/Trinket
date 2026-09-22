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
        XCTAssertTrue(button(AccessibilityID.Homestead.improveButton).label.contains("Upgrade"))
        attachSuccessScreenshot(named: "Blacksmith crafting entry")
        tapButton(AccessibilityID.Homestead.craftButton)
        assertExists(AccessibilityID.Homestead.forgeGrid)
        XCTAssertGreaterThan(any(AccessibilityID.Homestead.forgeGrid).frame.minY, app.frame.height * 0.35)
        attachSuccessScreenshot(named: "Blacksmith recipe grid")
        dragForgeSheet(to: 0.12)
        XCTAssertLessThan(any(AccessibilityID.Homestead.forgeGrid).frame.minY, app.frame.height * 0.25)
        tapButton(AccessibilityID.Homestead.forgeRecipe("blacksmith-dagger"))
        assertExists(AccessibilityID.Homestead.forgePreview)
        XCTAssertGreaterThan(any(AccessibilityID.Homestead.forgePreview).frame.minY, app.frame.height * 0.25)
        XCTAssertLessThan(
            button(AccessibilityID.Homestead.forgeButton).frame.minY - button(AccessibilityID.Homestead.forgeResult).frame.maxY,
            180,
        )
        XCTAssertFalse(button(AccessibilityID.Homestead.improveButton).isHittable)
        attachSuccessScreenshot(named: "Blacksmith forge preview")
        tapButton(AccessibilityID.Homestead.forgeButton)
        assertExists(AccessibilityID.Homestead.forgeDetail)
        assertExists(AccessibilityID.Homestead.forgeAdded)
        XCTAssertFalse(button(AccessibilityID.Homestead.forgeButton).exists)
        attachSuccessScreenshot(named: "Blacksmith forged item detail")
        tapButton(AccessibilityID.Homestead.forgeDone)
        assertExists(AccessibilityID.Homestead.forgeGrid)
        dragForgeSheet(to: 0.98)
        assertDoesNotExist(AccessibilityID.Homestead.forgeGrid)
        assertExists(AccessibilityID.Homestead.currentEffects)
        tapButton(AccessibilityID.Homestead.craftButton)
        assertExists(AccessibilityID.Homestead.forgeGrid)
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
        attachSuccessScreenshot(named: "Unbuilt Homestead buildings without upgrade glow")
        tapButton(AccessibilityID.Homestead.node(title: "Blacksmith"))
        homestead.assertNodeDetail(named: "Blacksmith")
        assertExists(AccessibilityID.Homestead.progress(tier: 0))
        XCTAssertTrue(button(AccessibilityID.Homestead.improveButton).label.contains("Build"))
        XCTAssertFalse(button(AccessibilityID.Homestead.craftButton).exists)
        attachSuccessScreenshot(named: "Unbuilt Blacksmith desaturated")
        tapButton(AccessibilityID.Homestead.improveButton)
        assertExists(AccessibilityID.Homestead.upgradeSheet)
        XCTAssertTrue(button(AccessibilityID.Homestead.upgradeButton).isEnabled)
        tapButton(AccessibilityID.Homestead.upgradeButton)
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        assertExists(AccessibilityID.Homestead.progress(tier: 1))
        assertExists(AccessibilityID.Homestead.craftButton)
        attachSuccessScreenshot(named: "Blacksmith first-build reveal begins")
        tapButton(AccessibilityID.Homestead.backButton)
        XCTAssertEqual(button(AccessibilityID.Homestead.node(title: "Blacksmith")).value as? String, "1 of 4 upgrades")
        attachSuccessScreenshot(named: "Built and unbuilt Homestead artwork")
        tapButton(AccessibilityID.Homestead.node(title: "Blacksmith"))
        homestead.assertNodeDetail(named: "Blacksmith")
        assertExists(AccessibilityID.Homestead.progress(tier: 1))
        attachSuccessScreenshot(named: "Built Blacksmith full color on return")
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
