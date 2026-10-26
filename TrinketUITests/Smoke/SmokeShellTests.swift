import TrinketFeatureSupport
import XCTest

final class SmokeShellTests: TrinketUITestCase {
    func testTabShellsAreReachable() {
        launchApp(arguments: TestLaunchArg.allForTab("play"))
        assertExists(AccessibilityID.Play.campaignModeCard, timeout: 10)

        tabBar.select(.collection)
        assertExists(AccessibilityID.Collection.heroesCategory, timeout: 10)

        tabBar.select(.homestead)
        assertExists(AccessibilityID.Homestead.resourceWallet, timeout: 10)

        tabBar.select(.options)
        assertExists(AccessibilityID.Screen.options, timeout: 10)
        assertExistsAfterScroll(AccessibilityID.Options.resetProgressButton, requireHittable: true)
        tapButton(AccessibilityID.Options.resetProgressButton)
        let resetAlert = app.alerts.firstMatch
        tapWhenReady(resetAlert.buttons.matching(identifier: AccessibilityID.Options.resetProgressCancel).firstMatch)
        waitUntil("Cancelling Reset must close its confirmation") { !resetAlert.exists }
        tabBar.select(.play)
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
        XCTAssertFalse(app.buttons[AccessibilityID.Tab.play].exists)
        let heroName = any(AccessibilityID.Onboarding.heroScreen)
            .staticTexts[AccessibilityID.Onboarding.selectedName].label
        XCTAssertFalse(heroName.isEmpty)

        let heroConfirmID = AccessibilityID.Onboarding.confirm(role: .hero)
        any(heroConfirmID).trinketTapWhenReady(timeout: 15)

        assertExists(AccessibilityID.Onboarding.companionScreen, timeout: 15)
        let companionName = any(AccessibilityID.Onboarding.companionScreen)
            .staticTexts[AccessibilityID.Onboarding.selectedName].label
        XCTAssertFalse(companionName.isEmpty)

        let companionConfirmID = AccessibilityID.Onboarding.confirm(role: .companion)
        any(companionConfirmID).trinketTapWhenReady(timeout: 15)

        XCTAssertTrue(
            app.buttons[AccessibilityID.Tab.play].trinketWaitForExistence(timeout: 15),
            "Play navigation did not appear after onboarding",
        )
        play.assertLoaded(timeout: 15)
        relaunchApp()
        assertDoesNotExist(AccessibilityID.Onboarding.heroScreen)
        assertDoesNotExist(AccessibilityID.Onboarding.companionScreen)
        play.assertLoaded()
        tabBar.select(.collection)
        let heroCard = AccessibilityID.CombatantDetail.collectionCard(name: heroName)
        assertExistsAfterScroll(heroCard, requireHittable: true)
        XCTAssertFalse(button(heroCard).label.hasSuffix(", locked"), "The selected starter hero must remain unlocked")
        let companionCard = AccessibilityID.CombatantDetail.collectionCard(name: companionName)
        assertExistsAfterScroll(companionCard, requireHittable: true)
        XCTAssertFalse(button(companionCard).label.hasSuffix(", locked"), "The selected starter companion must remain unlocked")
    }
}
