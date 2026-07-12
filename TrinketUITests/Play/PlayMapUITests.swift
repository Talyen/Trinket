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

    func testStageEnemyArtInspection() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        play.assertChapterHeader(number: 1)
        assertExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 1))
        XCTAssertFalse(button(AccessibilityID.Play.stageNode(chapter: 1, stage: 1)).exists)

        button(AccessibilityID.Play.enemyArt(chapter: 1, stage: 1)).tap()
        assertExists(AccessibilityID.CombatantDetail.header(name: "Skeleton"))
        assertExists(AccessibilityID.CombatantDetail.statsSection)
        dismissSheet()
        assertDoesNotExist(AccessibilityID.CombatantDetail.header(name: "Skeleton"), timeout: 2)
    }

    func testChapterOverviewShowsFiveStagesWithoutRewardsCompactPartyAndBoss() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        for stage in 1 ... 5 {
            assertExists(AccessibilityID.Play.stageRow(chapter: 1, stage: stage))
        }
        assertExists(AccessibilityID.Play.activeStageDetail)
        assertDoesNotExist(AccessibilityID.Play.stageRewards)
        assertExists(AccessibilityID.Play.stagePartyControl)
        assertDoesNotExist(AccessibilityID.Play.battlePartyInlinePicker)
        assertDoesNotExist(AccessibilityID.Play.bossBadge(chapter: 1, stage: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: "Rewards").count, 0)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Your Party").count, 0)
    }

    func testChapterPickerBrowsesCompletedChapterReadOnly() {
        launchApp(arguments: chapterOneCompleteArgs)

        play.assertLoaded()
        play.assertChapterHeader(number: 2)
        button(AccessibilityID.Play.chapterPicker).tap()
        app.buttons["Chapter 1"].tap()

        assertExists(AccessibilityID.Play.chapterTitle(number: 1))
        for stage in 1 ... 5 {
            assertExists(AccessibilityID.Play.stageRow(chapter: 1, stage: stage))
        }
        assertDoesNotExist(AccessibilityID.Play.activeStageDetail)
    }

    func testNonBattleStubStageCanComplete() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs + TestLaunchArg.completedStages(["chapter-1-stage-1"]))

        play.openStage(chapter: 1, stage: 2)

        assertExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 3))
        XCTAssertFalse(button(AccessibilityID.Play.stageNode(chapter: 1, stage: 2)).exists)
    }

    func testBattleUsesCompactPartyPicker() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()

        assertDoesNotExist(AccessibilityID.Play.battlePartyInlinePicker)
        button(AccessibilityID.Play.stagePartyControl).tap()
        assertExists(AccessibilityID.Play.stagePartyPickerSheet)
        assertExists(AccessibilityID.Play.battlePartyHeroControl)
        assertExists(AccessibilityID.Play.battlePartyPetControl)

        button(AccessibilityID.Play.battlePartyHeroControl).tap()
        assertExists(AccessibilityID.Play.battlePartyOption(for: "Hero", combatantName: "Wizard"))
        button(AccessibilityID.Play.battlePartyOption(for: "Hero", combatantName: "Wizard")).tap()
        XCTAssertEqual(
            app.descendants(matching: .any)[AccessibilityID.Play.battlePartyHeroControl].value as? String,
            "Wizard"
        )

        button(AccessibilityID.Play.battlePartyPetControl).tap()
        assertExists(AccessibilityID.Play.battlePartyOption(for: "Pet", combatantName: "Bear"))
        button(AccessibilityID.Play.battlePartyOption(for: "Pet", combatantName: "Bear")).tap()
        XCTAssertEqual(
            app.descendants(matching: .any)[AccessibilityID.Play.battlePartyPetControl].value as? String,
            "Bear"
        )

        dismissSheet()
        assertDoesNotExist(AccessibilityID.Play.stagePartyPickerSheet, timeout: 2)

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
                "chapter-1-stage-4"
            ]))

        play.assertLoaded()
        play.assertChapterHeader(number: 1)
        assertExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 5))
        assertDoesNotExist(AccessibilityID.Play.chapterLocked(number: 2))
    }
}
