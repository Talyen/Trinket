import TrinketFeatureSupport
import XCTest

final class ShopPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testShop() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allForShop()
                    + TestLaunchArg.completedStages((1 ... 7).map { "chapter-2-stage-\($0)" })
                    + ["-starting-gold", "200"]))
            assertExists(AccessibilityID.Shop.goldBalance)
            let shop = ShopScreen(app: app)
            let shopScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            measured("shop-scroll", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch)
            }
            verifyScrollProbes(shopScrollProbes, app.scrollViews.firstMatch)
            measured("shop-purchase", iteration: iteration) {
                tapWhenReady(shop.offerCards.firstMatch)
                assertExists(shop.detailBuy)
                XCTAssertTrue(shop.detailBuy.isEnabled)
                tapWhenReady(shop.detailBuy)
                assertDoesNotExist(AccessibilityID.Shop.detailBuyButton)
            }
            measured("shop-return", iteration: iteration) {
                scrollUntilVisible(shop.leaveButton, swipingUp: true, requireHittable: true)
                tapWhenReady(shop.leaveButton)
                play.assertLoaded()
            }
        }
    }
}
