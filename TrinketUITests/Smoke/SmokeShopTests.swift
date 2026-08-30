import TrinketFeatureSupport
import XCTest

final class SmokeShopTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForShop() + TestLaunchArg.completedStages([
            "chapter-2-stage-1",
            "chapter-2-stage-2",
            "chapter-2-stage-3",
            "chapter-2-stage-4",
        ])
    }

    func testMerchantShopLoadsCriticalControls() {
        assertExists(AccessibilityID.Shop.encounterTitle, timeout: 20)
        assertExists(AccessibilityID.Shop.goldBalance, timeout: 20)
        assertExists(AccessibilityID.Shop.leaveButton, timeout: 20)

        let shop = ShopScreen(app: app)
        XCTAssertGreaterThan(shop.offerCards.count, 0, "Expected shop offer cards")
    }
}
