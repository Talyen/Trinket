import XCTest

final class PlayMapUITests: TrinketUITestCase {
    private var chapterOneCompleteArgs: [String] {
        TestLaunchArg.testLaunchArgs + TestLaunchArg.completedStages([
            "chapter-1-stage-1",
            "chapter-1-stage-2",
            "chapter-1-stage-3",
            "chapter-1-stage-4",
            "chapter-1-stage-5"
        ])
    }

    func testChapterAdvanceContinuesFromClearedChapter() {
        launchApp(arguments: chapterOneCompleteArgs)

        play.openCampaign()
        play.assertCampaignLoaded(number: 1)
        for stage in 1 ... 5 {
            assertDoesNotExist(AccessibilityID.Play.stageRow(chapter: 1, stage: stage))
        }
        assertDoesNotExist(AccessibilityID.Play.activeStageDetail)
        assertDoesNotExist(AccessibilityID.Play.chapterPicker)

        button(AccessibilityID.Play.chapterAdvance).tap()

        play.assertChapterHeader(number: 2)
        assertExists(AccessibilityID.Play.chapterTitle(number: 2))
        assertExists(AccessibilityID.Play.activeStageDetail)
        assertDoesNotExist(AccessibilityID.Play.chapterAdvance, timeout: 2)
    }

    func testNonBattleStubStageCanComplete() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs + TestLaunchArg.completedStages(["chapter-1-stage-1"]))

        play.openCampaign()
        play.openStage(chapter: 1, stage: 2)

        assertDoesNotExist(AccessibilityID.Play.stageRow(chapter: 1, stage: 2))
        assertExists(AccessibilityID.Play.stageRow(chapter: 1, stage: 3))
        assertDoesNotExist(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
    }

    /// Campaign compact party picker: confirm hero selection from combatant detail.
    func testBattleUsesCompactPartyPicker() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.openCampaign()

        assertDoesNotExist(AccessibilityID.Play.battlePartyInlinePicker)
        button(AccessibilityID.Play.stagePartyControl).tap()
        assertExists(AccessibilityID.Play.stagePartyPickerSheet)
        assertExists(AccessibilityID.Play.battlePartyHeroControl)

        button(AccessibilityID.Play.battlePartyHeroControl).tap()
        assertExists(AccessibilityID.Play.battlePartyOption(for: "Hero", combatantName: "Wizard"))
        button(AccessibilityID.Play.battlePartyOption(for: "Hero", combatantName: "Wizard")).tap()
        assertExists(AccessibilityID.Play.battlePartyDetail("wizard"))
        button(AccessibilityID.Play.selectBattlePartyOption(for: "Hero", combatantID: "wizard")).tap()
        XCTAssertTrue(
            button(AccessibilityID.Play.battlePartyHeroControl).label.localizedCaseInsensitiveContains("Wizard")
        )

        dismissSheet()
        assertDoesNotExist(AccessibilityID.Play.stagePartyPickerSheet, timeout: 2)
    }
}
