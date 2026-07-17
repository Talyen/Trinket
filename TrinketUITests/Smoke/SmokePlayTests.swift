import XCTest

final class SmokePlayTests: TrinketUITestCase {
    private var freshPlayArgs: [String] {
        [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
            "-battle-tick-interval",
            "1.0"
        ]
    }

    func testPlayScreenLoadsWithCampaignAndExploreChoices() {
        launchApp(arguments: freshPlayArgs)

        play.assertLoaded()
        assertExists(AccessibilityID.Play.campaignModeCard)
        assertExists(AccessibilityID.Play.exploreModeCard)
        XCTAssertEqual(app.buttons.matching(identifier: AccessibilityID.Play.campaignModeCard).count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: AccessibilityID.Play.exploreModeCard).count, 1)

        // Unimplemented placeholders and Explore's sub-modes do not leak into
        // the top-level chooser.
        assertDoesNotExist(AccessibilityID.Play.aspectsModeCard)
        assertDoesNotExist(AccessibilityID.Play.labyrinthModeCard)
        assertNoVisibleText("Reliquary Gauntlet")
        assertNoVisibleText("Astral Hunt")
        assertNoVisibleText("THE LINEAR JOURNEY")
        assertNoVisibleText("ADVENTURES AWAIT")
        assertNoVisibleText("Aspects · The Labyrinth")
        assertDoesNotExist(AccessibilityID.Play.chapterHeader(number: 1))
    }

    func testCampaignPartyPickerConfirmsSelectionFromCombatantDetail() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.openCampaign()
        button(AccessibilityID.Play.stagePartyControl).tap()
        assertExists(AccessibilityID.Play.stagePartyPickerSheet)

        button(AccessibilityID.Play.battlePartyHeroControl).tap()
        let wizardOption = AccessibilityID.Play.battlePartyOption(
            for: "Hero",
            combatantName: "Wizard"
        )
        assertExists(wizardOption)
        button(wizardOption).tap()

        assertExists(AccessibilityID.Play.battlePartyDetail("wizard"))
        button(AccessibilityID.Play.selectBattlePartyOption(for: "Hero", combatantID: "wizard")).tap()

        XCTAssertTrue(app.navigationBars["Party"].waitForExistence(timeout: Self.defaultTimeout))
        XCTAssertTrue(
            button(AccessibilityID.Play.battlePartyHeroControl).label.localizedCaseInsensitiveContains("Wizard")
        )
    }

    private func assertNoVisibleText(
        _ text: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let matches = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", text)
        )
        XCTAssertEqual(matches.count, 0, "Unexpected visible text '\(text)'", file: file, line: line)
    }
}
