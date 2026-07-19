import XCTest

/// Exhaustive merchant shop journey via deep link (kept out of smoke-full).
final class ShopFlowUITests: TrinketUITestCase {
    func testMerchantShopBrowseDetailPurchaseAndLeaveUnlocksNextStage() {
        // Deep-link opens stage 2-4 shop; prior stages completed so leave unlocks stage 5.
        launchApp(arguments: TestLaunchArg.allForShop() + TestLaunchArg.completedStages([
            "chapter-2-stage-1",
            "chapter-2-stage-2",
            "chapter-2-stage-3"
        ]))

        // Shell catalog (title/gold/leave/offers) lives in SmokeShopTests; wait once then journey.
        assertExists(AccessibilityID.Shop.leaveButton)

        let offerCards = app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH %@", " shop offer")
        )
        XCTAssertGreaterThan(offerCards.count, 0, "Expected shop offer cards")
        offerCards.element(boundBy: 0).tap()
        assertExists(AccessibilityID.Shop.detailBuyButton)
        dismissSheet()

        let buyButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Buy ")
        )
        var purchased = false
        for index in 0 ..< buyButtons.count {
            let buyButton = buyButtons.element(boundBy: index)
            if buyButton.exists, buyButton.isHittable, buyButton.isEnabled {
                buyButton.tap()
                purchased = true
                break
            }
        }
        XCTAssertTrue(purchased, "Expected at least one enabled shop Buy control")

        let leaveButton = button(AccessibilityID.Shop.leaveButton)
        scrollUntilVisible(leaveButton, swipingUp: true, requireHittable: true)
        tapButton(AccessibilityID.Shop.leaveButton)
        play.openCampaign()
        assertButtonExists(AccessibilityID.Play.stageAction(chapter: 2, stage: 5))
    }
}
