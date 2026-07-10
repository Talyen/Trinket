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
            "chapter-1-stage-10"
        ])
    }

    func testStageEnemyArtInspection() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        play.assertChapterHeader(number: 1)
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 1))

        button(AccessibilityID.Play.enemyArt(chapter: 1, stage: 1)).tap()
        assertExists(AccessibilityID.CombatantDetail.header(name: "Skeleton"))
        assertExists(AccessibilityID.CombatantDetail.statsSection)
        dismissSheet()
        assertDoesNotExist(AccessibilityID.CombatantDetail.header(name: "Skeleton"), timeout: 2)
    }

    func testNonBattleStubStageCanComplete() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs + TestLaunchArg.completedStages(["chapter-1-stage-1"]))

        play.openStage(chapter: 1, stage: 2)

        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 3))
        XCTAssertFalse(button(AccessibilityID.Play.stageNode(chapter: 1, stage: 2)).exists)
    }

    func testBattleUsesInlinePartyPicker() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()

        assertExists(AccessibilityID.Play.battlePartyInlinePicker)
        assertExists(AccessibilityID.Play.battlePartyHeroControl)
        assertExists(AccessibilityID.Play.battlePartyPetControl)

        button(AccessibilityID.Play.battlePartyHeroControl).tap()
        assertExists(AccessibilityID.Play.battlePartyPickerSheet(for: "Hero"))
        assertExists(AccessibilityID.Play.battlePartyOption(for: "Hero", combatantName: "Wizard"))

        button(AccessibilityID.Play.battlePartyOption(for: "Hero", combatantName: "Wizard")).tap()
        assertDoesNotExist(AccessibilityID.Play.battlePartyPickerSheet(for: "Hero"), timeout: 2)
        XCTAssertEqual(
            app.descendants(matching: .any)[AccessibilityID.Play.battlePartyHeroControl].value as? String,
            "Wizard"
        )

        play.startBattle(chapter: 1, stage: 1)
    }

    func testAspectBattleUsesInlinePartyPicker() {
        launchApp(arguments: chapterOneCompleteArgs)

        play.openModeHub()
        app.buttons[AccessibilityID.Play.aspectsModeCard].tap()
        app.buttons[AccessibilityID.Play.aspectRow("ironVein")].tap()

        assertExists(AccessibilityID.Play.aspectFloor("ironVein", floor: 1))
        assertExists(AccessibilityID.Play.battlePartyHeroControl)
        assertExists(AccessibilityID.Play.battlePartyPetControl)

        button(AccessibilityID.Play.battlePartyHeroControl).tap()
        assertExists(AccessibilityID.Play.battlePartyPickerSheet(for: "Hero"))
        button(AccessibilityID.Play.battlePartyOption(for: "Hero", combatantName: "Rogue")).tap()

        button(AccessibilityID.Play.battlePartyPetControl).tap()
        assertExists(AccessibilityID.Play.battlePartyPickerSheet(for: "Pet"))
        button(AccessibilityID.Play.battlePartyOption(for: "Pet", combatantName: "Bear")).tap()

        let beginFloor = app.buttons["Begin Floor"]
        XCTAssertTrue(beginFloor.waitForExistence(timeout: Self.defaultTimeout))
        XCTAssertTrue(beginFloor.isEnabled)
        beginFloor.tap()

        battle.assertPresented(timeout: 8)
    }

    func testLabyrinthBattleUsesInlinePartyPicker() {
        launchApp(arguments: chapterOneCompleteArgs)

        play.openModeHub()
        app.buttons[AccessibilityID.Play.labyrinthModeCard].tap()
        assertExists(AccessibilityID.Play.labyrinthMap)

        let fight = app.buttons["Fight"].firstMatch
        XCTAssertTrue(fight.waitForExistence(timeout: Self.defaultTimeout), "Labyrinth combat CTA not found")
        assertExists(AccessibilityID.Play.battlePartyHeroControl)
        assertExists(AccessibilityID.Play.battlePartyPetControl)

        fight.tap()

        battle.assertPresented(timeout: 8)
    }

    func testFinalStageOfChapterAutoAdvancesWithoutGate() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs
            + TestLaunchArg.completedStages([
                "chapter-1-stage-1",
                "chapter-1-stage-2",
                "chapter-1-stage-3",
                "chapter-1-stage-4",
                "chapter-1-stage-5",
                "chapter-1-stage-6",
                "chapter-1-stage-7",
                "chapter-1-stage-8",
                "chapter-1-stage-9"
            ]))

        play.assertLoaded()
        play.assertChapterHeader(number: 1)
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 10))
        assertDoesNotExist(AccessibilityID.Play.chapterLocked(number: 2))
    }
}
