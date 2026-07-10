import XCTest

/// Exhaustive mystery recruit journey via deep link (kept out of smoke-full).
final class MysteryRecruitUITests: TrinketUITestCase {
    func testRecruitMysteryUnlockFlow() {
        // Fresh save (no seed) so Wolf is locked; stage 1 complete so leave unlocks stage 3.
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
            "-battle-tick-interval",
            "1.0",
            "-launch-screen",
            "mystery"
        ] + TestLaunchArg.completedStages(["chapter-1-stage-1"]))

        assertExists(AccessibilityID.Mystery.encounterTitle)
        assertExists(AccessibilityID.Mystery.welcomeButton)
        button(AccessibilityID.Mystery.welcomeButton).tap()

        assertExists(AccessibilityID.Mystery.unlockName)
        assertExists(AccessibilityID.Mystery.unlockCard(name: "Wolf"))
        button(AccessibilityID.Mystery.unlockCard(name: "Wolf")).tap()
        assertExists(AccessibilityID.CombatantDetail.header(name: "Wolf"))
        // Detail sheets resize on swipe; dismiss via Done like shop item detail.
        tapButton("Done")
        _ = button(AccessibilityID.Mystery.continueButton).waitForExistence(timeout: Self.defaultTimeout)

        assertExists(AccessibilityID.Mystery.continueButton)
        tapButton(AccessibilityID.Mystery.continueButton)
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 3))
    }
}
