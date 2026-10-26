import TrinketFeatureSupport
import XCTest

final class SmokeShellTests: TrinketUITestCase {
    func testNewCareerSurvivesRelaunchAndNavigatesEveryTab() {
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
        for name in [heroName, companionName] {
            tapButtonAfterScroll(AccessibilityID.CombatantDetail.collectionCard(name: name))
            combatantDetail.assertLoaded(for: name)
            dismissSheet(AccessibilityID.CombatantDetail.header(name: name))
        }

        tabBar.select(.homestead)
        assertExists(AccessibilityID.Homestead.resourceWallet)
        tabBar.select(.options)
        assertExists(AccessibilityID.Screen.options)
        tabBar.select(.play)
        assertExists(AccessibilityID.Play.campaignModeCard)
    }
}
