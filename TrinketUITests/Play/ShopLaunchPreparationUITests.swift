import TrinketFeatureSupport
import XCTest

final class ShopLaunchPreparationUITests: TrinketUITestCase {
    func testInterruptedShopLaunchKeepsCoverUntilRestartCompletes() {
        launchApp(arguments: TestLaunchArg.allForShop() + ["-launch-preparation-delay", "8"], waitForPreparation: false)
        assertExists(AccessibilityID.Screen.launchWarmup)
        XCTAssertFalse(any(AccessibilityID.Shop.goldBalance).exists, "Shop controls appeared before launch preparation finished")

        app.terminate()
        app.launch()
        waitForLaunchPreparation()
        assertExists(AccessibilityID.Shop.goldBalance)
    }
}
