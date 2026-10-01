import TrinketFeatureSupport
import XCTest

final class SmokeShellTests: TrinketUITestCase {
    func testTabShellsAreReachable() {
        launchApp(arguments: TestLaunchArg.allForTab("play"))
        play.assertLoaded(timeout: 10)
        assertExists(AccessibilityID.Play.campaignModeCard, timeout: 10)

        tabBar.selectCollection()
        collection.assertLoaded(timeout: 10)
        assertExists(AccessibilityID.Collection.heroesCategory, timeout: 10)

        tabBar.selectHomestead()
        homestead.assertLoaded(timeout: 10)
        assertExists(AccessibilityID.Homestead.resourceWallet, timeout: 10)

        tabBar.selectOptions()
        options.assertLoaded(timeout: 10)
        let haptics = app.descendants(matching: .any)[AccessibilityID.Options.hapticsToggle]
        assertExists(AccessibilityID.Options.hapticsToggle, timeout: 10)
        let initialValue = haptics.value as? String
        // XCUITest exposes the whole Toggle row; its center falls in the gap before the switch.
        XCTAssertTrue(haptics.isHittable)
        haptics.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        if let initial = initialValue {
            let changed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value != %@", initial), object: haptics,
            )
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: Self.defaultTimeout), .completed)
        }
        tabBar.selectPlay()
        play.assertLoaded(timeout: 10)
    }
}

final class StarterOnboardingSmokeTests: TrinketUITestCase {
    func testStarterRouletteLandsOnGameModeHub() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
        ])

        assertExists(AccessibilityID.Onboarding.heroScreen, timeout: 15)
        XCTAssertEqual(app.tabBars.count, 0)

        let heroConfirmID = AccessibilityID.Onboarding.confirm(role: .hero)
        assertExists(heroConfirmID, timeout: 15)
        let heroConfirm = app.descendants(matching: .any)[heroConfirmID]
        tapWhenReady(heroConfirm)

        assertExists(AccessibilityID.Onboarding.companionScreen, timeout: 15)

        let companionConfirmID = AccessibilityID.Onboarding.confirm(role: .companion)
        assertExists(companionConfirmID, timeout: 15)
        let companionConfirm = app.descendants(matching: .any)[companionConfirmID]
        tapWhenReady(companionConfirm)

        XCTAssertTrue(
            app.tabBars.firstMatch.trinketWaitForExistence(timeout: 15),
            "Tab bar did not appear after onboarding",
        )
        play.assertLoaded(timeout: 15)
    }
}
