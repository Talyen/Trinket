import XCTest

final class SmokeMysteryRecruitTests: TrinketUITestCase {
    func testRecruitMysteryUnlockFlow() {
        // Fresh save (no seed) so Wolf is locked and stage 1-2 presents the recruit encounter.
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
            "-battle-tick-interval",
            "1.0"
        ] + TestLaunchArg.completedStages(["chapter-1-stage-1"]))

        play.assertLoaded()
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 2))
        button(AccessibilityID.Play.stageNode(chapter: 1, stage: 2)).tap()

        assertExists(AccessibilityID.Mystery.encounterTitle)
        assertExists(AccessibilityID.Mystery.welcomeButton)
        button(AccessibilityID.Mystery.welcomeButton).tap()

        assertExists(AccessibilityID.Mystery.unlockName)
        assertExists(AccessibilityID.Mystery.unlockCard(name: "Wolf"))
        button(AccessibilityID.Mystery.unlockCard(name: "Wolf")).tap()
        assertExists(AccessibilityID.CombatantDetail.header(name: "Wolf"))
        app.swipeDown()
        _ = button(AccessibilityID.Mystery.continueButton).waitForExistence(timeout: Self.defaultTimeout)

        assertExists(AccessibilityID.Mystery.continueButton)
        tapButton(AccessibilityID.Mystery.continueButton)
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 3))
    }
}
