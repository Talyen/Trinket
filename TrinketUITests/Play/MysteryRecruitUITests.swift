import XCTest

/// Exhaustive Mystery encounter journeys via deep link (kept out of smoke-full).
final class MysteryRecruitUITests: TrinketUITestCase {
    func testOrdinaryMysteryShowsBothChoicesAndRewards() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
            "-launch-screen",
            "mystery"
        ]
            + TestLaunchArg.completedStages(["chapter-1-stage-1"])
            + TestLaunchArg.mysteryRecruit(eventID: "fairy-ring"))

        let stepInside = button(AccessibilityID.Mystery.choiceButton(choiceID: "step-inside"))
        let pluckCap = button(AccessibilityID.Mystery.choiceButton(choiceID: "pluck-cap"))
        let confirm = button(AccessibilityID.Mystery.confirmChoiceButton)
        assertExists(stepInside)
        assertExists(pluckCap)
        assertExists(confirm)
        XCTAssertFalse(confirm.isEnabled)
        XCTAssertTrue(stepInside.label.contains("Gold"))
        XCTAssertTrue(stepInside.label.contains("25"))
        XCTAssertFalse(stepInside.label.contains("+"))
        XCTAssertTrue(pluckCap.label.contains("Crystal"))
        XCTAssertTrue(pluckCap.label.contains("3"))
        XCTAssertFalse(pluckCap.label.contains("+"))

        assertExistsAfterScroll(
            AccessibilityID.Mystery.choiceButton(choiceID: "pluck-cap"),
            requireHittable: true
        )
        tapButton(AccessibilityID.Mystery.choiceButton(choiceID: "pluck-cap"))
        assertExistsAfterScroll(AccessibilityID.Mystery.confirmChoiceButton, requireHittable: true)
        XCTAssertTrue(confirm.isEnabled)
        tapButton(AccessibilityID.Mystery.confirmChoiceButton)
        assertExists(AccessibilityID.Mystery.rewardTitle)
    }

    func testCompanionRecruitRevealAndContinue() {
        // Fresh save (no seed) so Bear is locked; stage 1 complete so leave unlocks stage 3.
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
            "-battle-tick-interval",
            "1.0",
            "-launch-screen",
            "mystery"
        ]
            + TestLaunchArg.completedStages(["chapter-1-stage-1"])
            + TestLaunchArg.mysteryRecruit(eventID: "recruit-bear"))

        assertExists(AccessibilityID.Mystery.unlockCard(name: "Bear"))
        assertExists(AccessibilityID.Mystery.unlockName)
        assertExists(AccessibilityID.Mystery.continueButton)
        tapButton(AccessibilityID.Mystery.continueButton)
        play.openCampaign()
        assertExists(AccessibilityID.Play.stageRow(chapter: 1, stage: 3))
    }
}
