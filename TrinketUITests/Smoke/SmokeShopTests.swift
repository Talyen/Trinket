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
        assertExists(AccessibilityID.Shop.encounterTitle)
        assertExists(AccessibilityID.Shop.goldBalance)
        assertExists(AccessibilityID.Shop.leaveButton)

        let offerCards = app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH %@", " shop offer")
        )
        XCTAssertGreaterThan(offerCards.count, 0, "Expected shop offer cards")
    }
}
