import XCTest

final class SmokeShopTests: TrinketUITestCase {
    func testMerchantShopLoadsCriticalControls() {
        // Deep-link opens stage 2-4 shop; prior stages completed so leave would unlock stage 5.
        launchApp(arguments: TestLaunchArg.allForShop() + TestLaunchArg.completedStages([
            "chapter-2-stage-1",
            "chapter-2-stage-2",
            "chapter-2-stage-3"
        ]))

        assertExists(AccessibilityID.Shop.encounterTitle)
        assertExists(AccessibilityID.Shop.encounterGreeting)
        assertExists(AccessibilityID.Shop.goldBalance)
        assertExists(AccessibilityID.Shop.leaveButton)

        let offerCards = app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH %@", " shop offer")
        )
        XCTAssertGreaterThan(offerCards.count, 0, "Expected shop offer cards")
    }
}
