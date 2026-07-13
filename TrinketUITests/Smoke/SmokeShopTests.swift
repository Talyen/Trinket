import XCTest

final class SmokeShopTests: TrinketUITestCase {
    func testMerchantShopBrowseDetailAndLeave() {
        // Deep-link opens stage 2-4 shop; prior stages completed so leave unlocks stage 5.
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
        let offerIdentifiers = (0 ..< offerCards.count).compactMap { index -> String? in
            let element = offerCards.element(boundBy: index)
            guard element.exists else { return nil }
            return element.identifier
        }
        XCTAssertEqual(
            Set(offerIdentifiers).count,
            offerIdentifiers.count,
            "Shop offer accessibility ids must be unique even when display names collide"
        )
        offerCards.element(boundBy: 0).tap()
        assertExists(AccessibilityID.Shop.detailBuyButton)
        dismissSheet()
        _ = button(AccessibilityID.Shop.leaveButton).waitForExistence(timeout: Self.defaultTimeout)

        let buyButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Buy ")
        )
        for index in 0 ..< buyButtons.count {
            let buyButton = buyButtons.element(boundBy: index)
            if buyButton.exists, buyButton.isHittable, buyButton.isEnabled {
                buyButton.tap()
                assertExists(AccessibilityID.Shop.purchaseConfirmation)
                break
            }
        }

        // Offer grid can grow taller than the viewport; scroll the Leave button into view
        // before tapping so a covered/off-screen element doesn't swallow the tap.
        for _ in 0 ..< 6 {
            let leaveButton = button(AccessibilityID.Shop.leaveButton)
            if leaveButton.exists, leaveButton.isHittable {
                break
            }
            app.swipeUp()
        }
        tapButton(AccessibilityID.Shop.leaveButton)
        play.openCampaign()
        assertButtonExists(AccessibilityID.Play.stageAction(chapter: 2, stage: 5))
    }
}
