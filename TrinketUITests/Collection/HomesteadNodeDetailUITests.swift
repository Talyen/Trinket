import TrinketFeatureSupport
import XCTest

final class HomesteadNodeDetailUITests: TrinketUITestCase {
    func testHomesteadBuildingUpgrades() {
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
        assertExists(AccessibilityID.Homestead.upgradeEffects)
        XCTAssertTrue(button(AccessibilityID.Homestead.upgradeButton).isEnabled)
        tapButton(AccessibilityID.Homestead.upgradeButton)
        assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
        assertExists(AccessibilityID.Homestead.progress(tier: 1))
        assertExists(AccessibilityID.Homestead.craftButton)
        tapButton(AccessibilityID.Homestead.backButton)
        assertExists(AccessibilityID.Homestead.gallery)
        goBack()
        homestead.assertLoaded()
    }
}
