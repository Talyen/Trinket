import XCTest

final class SmokeShopTests: TrinketUITestCase {
    func testMerchantShopBrowseDetailAndLeave() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
            "-battle-tick-interval",
            "1.0"
        ] + TestLaunchArg.completedStages([
            "chapter-1-stage-1",
            "chapter-1-stage-2",
            "chapter-1-stage-3"
        ]))

        play.assertLoaded()
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 4))
        button(AccessibilityID.Play.stageNode(chapter: 1, stage: 4)).tap()

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
        app.swipeDown()

        // Purchase when an offer is affordable (stage 1–3 gold ≈ 34); otherwise leave.
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

        button(AccessibilityID.Shop.leaveButton).tap()
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 5))
    }
}
