import XCTest

final class PlayMapUITests: TrinketUITestCase {
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
        XCTAssertFalse(app.alerts.element.exists)
    }

    func testFinalStageShowsLockedNextChapter() {
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
            ])
            + TestLaunchArg.mapScrollTarget("chapter-gate-placeholder-2"))

        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 10))
        assertExists(AccessibilityID.Play.chapterLocked(number: 2))
    }

    func testHomesteadNodeDetail() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        homestead.assertLoaded()
        homestead.openNode(named: "Wheat Field")
        homestead.assertNodeDetail(named: "Wheat Field")
    }
}
