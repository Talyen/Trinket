import TrinketFeatureSupport
import XCTest

final class SmokeShellTests: TrinketUITestCase {
    func testTabShellsAreReachable() {
        launchApp(arguments: TestLaunchArg.allForTab("play"))
        assertExists(AccessibilityID.Play.campaignModeCard, timeout: 10)

        tabBar.selectCollection()
        assertExists(AccessibilityID.Collection.heroesCategory, timeout: 10)

        tabBar.selectHomestead()
        assertExists(AccessibilityID.Homestead.resourceWallet, timeout: 10)

        tabBar.selectOptions()
        assertExists(AccessibilityID.Screen.options, timeout: 10)
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
        let heroName = any(AccessibilityID.Onboarding.selectedName).label
        XCTAssertFalse(heroName.isEmpty)

        let heroConfirmID = AccessibilityID.Onboarding.confirm(role: .hero)
        any(heroConfirmID).trinketTapWhenReady(timeout: 15)

        assertExists(AccessibilityID.Onboarding.companionScreen, timeout: 15)
        let companionName = any(AccessibilityID.Onboarding.selectedName).label
        XCTAssertFalse(companionName.isEmpty)

        let companionConfirmID = AccessibilityID.Onboarding.confirm(role: .companion)
        any(companionConfirmID).trinketTapWhenReady(timeout: 15)

        XCTAssertTrue(
            app.tabBars.firstMatch.trinketWaitForExistence(timeout: 15),
            "Tab bar did not appear after onboarding",
        )
        play.assertLoaded(timeout: 15)
        relaunchApp()
        assertDoesNotExist(AccessibilityID.Onboarding.heroScreen)
        assertDoesNotExist(AccessibilityID.Onboarding.companionScreen)
        play.assertLoaded()
        tabBar.selectCollection()
        let heroCard = AccessibilityID.CombatantDetail.collectionCard(name: heroName)
        assertExistsAfterScroll(heroCard, requireHittable: true)
        XCTAssertFalse(button(heroCard).label.hasSuffix(", locked"), "The selected starter hero must remain unlocked")
        let companionCard = AccessibilityID.CombatantDetail.collectionCard(name: companionName)
        assertExistsAfterScroll(companionCard, requireHittable: true)
        XCTAssertFalse(button(companionCard).label.hasSuffix(", locked"), "The selected starter companion must remain unlocked")
    }
}
