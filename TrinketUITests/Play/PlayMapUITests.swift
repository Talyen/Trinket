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

        play.openCampaign()
        play.assertCampaignLoaded(number: 1)
        assertExists(AccessibilityID.Play.stageRow(chapter: 1, stage: 1))
        assertDoesNotExist(AccessibilityID.Play.stageNode(chapter: 1, stage: 1))

        button(AccessibilityID.Play.enemyArt(chapter: 1, stage: 1)).tap()
        assertExists(AccessibilityID.CombatantDetail.header(name: "Slime"))
        assertExists(AccessibilityID.CombatantDetail.statsSection)
        dismissSheet()
        assertDoesNotExist(AccessibilityID.CombatantDetail.header(name: "Slime"), timeout: 2)
    }

    func testChapterOverviewHidesCompletedStagesAndShowsActiveAndFutureStages() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs + TestLaunchArg.completedStages([
            "chapter-1-stage-1",
            "chapter-1-stage-2"
        ]))

        play.openCampaign()
        for stage in 1 ... 2 {
            assertDoesNotExist(AccessibilityID.Play.stageRow(chapter: 1, stage: stage))
        }
        for stage in 3 ... 5 {
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

    func testBattleUsesCompactPartyPicker() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.openCampaign()

        assertDoesNotExist(AccessibilityID.Play.battlePartyInlinePicker)
        button(AccessibilityID.Play.stagePartyControl).tap()
        assertExists(AccessibilityID.Play.stagePartyPickerSheet)
        assertExists(AccessibilityID.Play.battlePartyHeroControl)
        assertExists(AccessibilityID.Play.battlePartyCompanionControl)
        XCTAssertTrue(app.navigationBars["Party"].waitForExistence(timeout: Self.defaultTimeout))
        XCTAssertFalse(app.buttons["Done"].exists)
        XCTAssertFalse(app.staticTexts["Choose who enters battle"].exists)

        button(AccessibilityID.Play.battlePartyHeroControl).tap()
        XCTAssertTrue(app.navigationBars["Choose Hero"].waitForExistence(timeout: Self.defaultTimeout))
        XCTAssertFalse(app.buttons["Party"].exists)
        assertExists(AccessibilityID.Play.battlePartyOption(for: "Hero", combatantName: "Wizard"))
        button(AccessibilityID.Play.battlePartyOption(for: "Hero", combatantName: "Wizard")).tap()
        XCTAssertTrue(app.staticTexts["Wizard"].waitForExistence(timeout: Self.defaultTimeout))

        button(AccessibilityID.Play.battlePartyCompanionControl).tap()
        assertExists(AccessibilityID.Play.battlePartyOption(for: "Companion", combatantName: "Bear"))
        button(AccessibilityID.Play.battlePartyOption(for: "Companion", combatantName: "Bear")).tap()
        XCTAssertTrue(app.staticTexts["Bear"].waitForExistence(timeout: Self.defaultTimeout))

        dismissSheet()
        assertDoesNotExist(AccessibilityID.Play.stagePartyPickerSheet, timeout: 2)

        play.startBattle(chapter: 1, stage: 1)
    }

    func testAspectBattleUsesInlinePartyPicker() {
        launchApp(arguments: chapterOneCompleteArgs)

        play.openAspects()
        app.buttons[AccessibilityID.Play.aspectRow("ironVein")].tap()

        assertExists(AccessibilityID.Play.aspectFloor("ironVein", floor: 1))
        assertExists(AccessibilityID.Play.battlePartyHeroControl)
        assertExists(AccessibilityID.Play.battlePartyCompanionControl)

        button(AccessibilityID.Play.battlePartyHeroControl).tap()
        assertExists(AccessibilityID.Play.battlePartyPickerSheet(for: "Hero"))
        button(AccessibilityID.Play.battlePartyOption(for: "Hero", combatantName: "Rogue")).tap()

        button(AccessibilityID.Play.battlePartyCompanionControl).tap()
        assertExists(AccessibilityID.Play.battlePartyPickerSheet(for: "Companion"))
        button(AccessibilityID.Play.battlePartyOption(for: "Companion", combatantName: "Bear")).tap()

        let beginFloor = AccessibilityID.Play.aspectBeginFloor("ironVein", floor: 1)
        assertButtonExists(beginFloor)
        XCTAssertTrue(button(beginFloor).isEnabled)
        tapButton(beginFloor)

        battle.assertPresented(timeout: 8)
    }

    func testLabyrinthBattleUsesInlinePartyPicker() {
        // Deep-link straight to The Labyrinth map — skip Explore hub navigation.
        launchApp(arguments: chapterOneCompleteArgs + TestLaunchArg.screen("labyrinth"))

        assertExists(AccessibilityID.Play.labyrinthMap)
        let combatActions = app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH %@", " labyrinth combat action")
        )
        XCTAssertGreaterThan(combatActions.count, 0, "Labyrinth combat CTA not found")
        assertExists(AccessibilityID.Play.battlePartyHeroControl)
        assertExists(AccessibilityID.Play.battlePartyCompanionControl)

        combatActions.element(boundBy: 0).tap()

        battle.assertPresented(timeout: 8)
    }

    func testFinalStageOfChapterOffersAdvanceInsteadOfAutoJump() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs
            + TestLaunchArg.completedStages([
                "chapter-1-stage-1",
                "chapter-1-stage-2",
                "chapter-1-stage-3",
                "chapter-1-stage-4"
            ]))

        play.openCampaign()
        play.assertCampaignLoaded(number: 1)
        for stage in 1 ... 4 {
            assertDoesNotExist(AccessibilityID.Play.stageRow(chapter: 1, stage: stage))
        }
        assertExists(AccessibilityID.Play.stageRow(chapter: 1, stage: 5))
        assertDoesNotExist(AccessibilityID.Play.chapterAdvance)
        assertDoesNotExist(AccessibilityID.Play.chapterLocked(number: 2))
    }
}
