import TrinketFeatureSupport
import XCTest

final class PlayMapUITests: TrinketUITestCase {
    private var chapterOneCompleteArgs: [String] {
        TestLaunchArg.testLaunchArgs + TestLaunchArg.completedStages([
            "chapter-1-stage-1",
            "chapter-1-stage-2",
            "chapter-1-stage-3",
            "chapter-1-stage-4",
            "chapter-1-stage-5",
            "chapter-1-stage-6",
            "chapter-1-stage-7",
            "chapter-1-stage-8",
            "chapter-1-stage-9",
            "chapter-1-stage-10",
        ])
    }

    func testCompletedChapterAutomaticallyContinuesToNextChapter() {
        launchApp(arguments: chapterOneCompleteArgs)

        play.openCampaign()
        play.assertCampaignLoaded(number: 2)
        play.assertChapterHeader(number: 2)
        assertExists(AccessibilityID.Play.chapterTitle(number: 2))
        assertExists(AccessibilityID.Play.activeStageDetail)
    }

    /// Campaign party picker: swap a hero directly from the shared carousel sheet.
    func testBattleUsesCompactPartyPicker() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.openCampaign()

        button(AccessibilityID.Play.stagePartyControl).tap()
        assertExists(AccessibilityID.Play.stagePartyPickerSheet)
        assertExists(AccessibilityID.Play.battlePartyShelf(for: "Hero"))
        assertExists(AccessibilityID.Play.battlePartyShelf(for: "Companion"))

        let heroOptionID = AccessibilityID.Play.battlePartyOption(
            for: "Hero",
            combatantID: "rogue"
        )
        assertExists(heroOptionID)
        button(heroOptionID).tap()
        XCTAssertEqual(button(heroOptionID).value as? String, "Selected")
        assertExists(AccessibilityID.Play.stagePartyPickerSheet)

        button(AccessibilityID.Play.battlePartyDone).tap()
        assertDoesNotExist(AccessibilityID.Play.stagePartyPickerSheet, timeout: 5)

        button(AccessibilityID.Play.stagePartyControl).tap()
        assertExists(AccessibilityID.Play.stagePartyPickerSheet)
        XCTAssertEqual(button(heroOptionID).value as? String, "Selected")
    }
}
