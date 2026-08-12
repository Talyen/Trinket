import TrinketFeatureSupport
import XCTest

/// Exhaustive merchant shop journey via deep link (kept out of smoke-full).
final class ShopFlowUITests: TrinketUITestCase {
    func testMerchantShopBrowseDetailPurchaseAndLeaveUnlocksNextStage() {
        // Deep-link opens stage 2-8 shop; prior stages completed so leave unlocks stage 9.
        // Seed grants ~22 gold from stage completions, which under-covers offer prices,
        // so grant a deterministic balance that makes every offer buyable.
        launchApp(arguments: TestLaunchArg.allForShop()
            + TestLaunchArg.completedStages([
                "chapter-2-stage-1",
                "chapter-2-stage-2",
                "chapter-2-stage-3",
                "chapter-2-stage-4",
                "chapter-2-stage-5",
                "chapter-2-stage-6",
                "chapter-2-stage-7",
            ])
            + ["-starting-gold", "200"])

        // Shell catalog (title/gold/leave/offers) lives in SmokeShopTests; wait once then journey.
        let offerCards = app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH %@", " shop offer")
        )
        let firstOfferCard = offerCards.firstMatch
        assertExists(firstOfferCard)
        tapWhenReady(firstOfferCard)
        assertExists(AccessibilityID.Shop.detailBuyButton)
        dismissSheet()

        let offerID = firstOfferCard.identifier.replacingOccurrences(of: " shop offer", with: "")
        let buyButton = button(AccessibilityID.Shop.buyButton(offerID: offerID))
        scrollUntilVisible(buyButton, swipingUp: true, requireHittable: true)
        XCTAssertTrue(buyButton.isEnabled, "Expected shop buy control to be enabled for \(offerID)")
        tapWhenReady(buyButton)

        let leaveButton = button(AccessibilityID.Shop.leaveButton)
        scrollUntilVisible(leaveButton, swipingUp: true, requireHittable: true)
        tapButton(AccessibilityID.Shop.leaveButton)
        play.openCampaign()
        assertButtonExists(AccessibilityID.Play.stageAction(chapter: 2, stage: 9))
    }
}
