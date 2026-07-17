import XCTest

/// Exhaustive mystery recruit journey via deep link (kept out of smoke-full).
final class MysteryRecruitUITests: TrinketUITestCase {
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
        XCTAssertEqual(any(AccessibilityID.Mystery.unlockEyebrow).label.uppercased(), "NEW COMPANION")
        XCTAssertEqual(any(AccessibilityID.Mystery.unlockSubtitle).label.uppercased(), "UNLOCKED")
        XCTAssertFalse(app.staticTexts["View Details"].exists)
        assertExists(AccessibilityID.Mystery.continueButton)
        XCTAssertEqual(any(AccessibilityID.Mystery.continueButton).label, "Recruit")
        tapButton(AccessibilityID.Mystery.continueButton)
        play.openCampaign()
        assertExists(AccessibilityID.Play.stageRow(chapter: 1, stage: 3))
    }

    func testHeroRecruitChoiceRevealsAndOpensDetail() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
            "-launch-screen",
            "mystery"
        ]
            + TestLaunchArg.completedStages(["chapter-1-stage-1"])
            + TestLaunchArg.mysteryRecruit(eventID: "recruit-ranger"))

        assertExists(AccessibilityID.Mystery.unlockCard(name: "Ranger"))
        assertExists(AccessibilityID.Mystery.unlockName)
        XCTAssertEqual(any(AccessibilityID.Mystery.unlockEyebrow).label.uppercased(), "NEW HERO")
        XCTAssertEqual(any(AccessibilityID.Mystery.unlockSubtitle).label.uppercased(), "UNLOCKED")
        XCTAssertFalse(app.staticTexts["View Details"].exists)
        button(AccessibilityID.Mystery.unlockCard(name: "Ranger")).tap()
        combatantDetail.assertLoaded(for: "Ranger")
    }
}
