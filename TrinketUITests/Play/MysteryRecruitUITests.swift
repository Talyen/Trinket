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
        // Do not open the combatant detail sheet here: detail hosts use
        // `.presentationContentInteraction(.resizes)`, so swipe-down does not
        // dismiss, and adding a Done control is a product decision.
        assertExists(AccessibilityID.Mystery.continueButton)
        tapButton(AccessibilityID.Mystery.continueButton)
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 3))
    }
}
