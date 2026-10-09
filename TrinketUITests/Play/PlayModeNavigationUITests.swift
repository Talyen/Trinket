import TrinketContent
import TrinketFeatureSupport
import XCTest

final class PlayModeNavigationUITests: TrinketUITestCase {
    func testRecruitContinueReturnsToCampaignWithTheCompanionUnlocked() {
        launchApp(arguments: TestLaunchArg.allUnseeded()
            + TestLaunchArg.completedStages(["chapter-1-stage-1"])
            + TestLaunchArg.mysteryRecruit(eventID: "recruit-bear") + ["-performance-mystery-map"])
        play.openCampaign()
        tapButton(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        assertExists(AccessibilityID.Mystery.unlockCard(name: "Bear"))
        assertExistsAfterScroll(AccessibilityID.Mystery.continueButton, requireHittable: true)
        tapButton(AccessibilityID.Mystery.continueButton)
        play.assertCampaignLoaded()
        assertExists(AccessibilityID.Play.stageAction(chapter: 1, stage: 3))
        tabBar.selectCollection()
        let bear = AccessibilityID.CombatantDetail.collectionCard(name: "Bear")
        assertExistsAfterScroll(bear, requireHittable: true)
        XCTAssertFalse(button(bear).label.hasSuffix(", locked"), "The recruited companion must be unlocked")
    }

    func testLabyrinthBossContinueOpensAUsableNextFloor() {
        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval("0.01", in: TestLaunchArg.allForScreen("labyrinth-map"))
            + ["-performance-labyrinth-node", "boss", "-performance-strong-party"])
        assertExists(AccessibilityID.Play.labyrinthMap)
        let boss = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@",
            AccessibilityID.Play.labyrinthNode(""), "Boss",
        )).firstMatch
        scrollUntilVisible(boss, swipingUp: true, requireHittable: true)
        tapWhenReady(boss)
        let action = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Play.labyrinthInspectorAction(""))).firstMatch
        tapWhenReady(action)
        battle.assertActive()
        tapWhenReady(battle.autoBattleToggle)
        assertExists(AccessibilityID.Battle.victory, timeout: 30)
        assertExistsAfterScroll(AccessibilityID.Battle.continueButton, requireHittable: true)
        tapButton(AccessibilityID.Battle.continueButton)
        assertExists(AccessibilityID.Play.labyrinthMap)
        tapButton(AccessibilityID.Play.labyrinthFloorMenu)
        tapButton(AccessibilityID.Play.labyrinthFloor(2))
        assertExists(AccessibilityID.Play.labyrinthMap)
    }

    func testVoyageEmbarkAndAbandonStayAbandonedAfterRelaunch() {
        launchApp(arguments: TestLaunchArg.allForTab("play"))
        play.openExplore()
        tapButton(AccessibilityID.Voyage.modeCard)
        assertExists(AccessibilityID.Voyage.screen)
        let embark = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", AccessibilityID.Voyage.action(""),
        )).firstMatch
        assertExists(embark)
        tapWhenReady(embark)
        assertExists(AccessibilityID.Voyage.options)
        tapButton(AccessibilityID.Voyage.options)
        tapButton(AccessibilityID.Voyage.abandon)
        tapButton(AccessibilityID.Voyage.confirmAbandon)
        assertExists(AccessibilityID.Voyage.refresh)
        assertDoesNotExist(AccessibilityID.Voyage.options)
        relaunchApp()
        play.openExplore()
        tapButton(AccessibilityID.Voyage.modeCard)
        assertExists(AccessibilityID.Voyage.refresh)
        assertDoesNotExist(AccessibilityID.Voyage.options)
    }

    func testSpireLockedFloorAndEnemyInspectionPreserveEligibleLaunch() throws {
        launchApp(arguments: TestLaunchArg.allForTab("play"))
        play.openExplore()
        tapButton(AccessibilityID.Play.spiresModeCard)
        assertExistsAfterScroll(AccessibilityID.Play.spireRow("ironVein"), requireHittable: true)
        tapButton(AccessibilityID.Play.spireRow("ironVein"))
        assertExists(AccessibilityID.Play.spireClimb("ironVein"))
        let locked = any(AccessibilityID.Play.spireFloor("ironVein", floor: 2))
        scrollUntilVisible(locked, swipingUp: true, requireHittable: true)
        locked.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        assertDoesNotExist(AccessibilityID.Battle.hand)
        XCTAssertFalse(button(AccessibilityID.Play.spireBeginFloor("ironVein", floor: 2)).exists)
        let art = any(AccessibilityID.Play.spireFloorEnemyArt("ironVein", floor: 1))
        scrollUntilVisible(art, swipingUp: false, requireHittable: true)
        tapWhenReady(art)
        let floor = try XCTUnwrap(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let enemy = try XCTUnwrap(GameContent.enemy(matching: floor.enemyID))
        let detail = AccessibilityID.CombatantDetail.header(name: enemy.combatant.name)
        assertExists(detail)
        dismissSheet(detail)
        tapButton(AccessibilityID.Play.spireBeginFloor("ironVein", floor: 1))
        battle.assertActive()
    }

    func testLabyrinthLockedTapPreservesSelectionAndBackgroundDismissesInspector() {
        launchApp(arguments: TestLaunchArg.allForScreen("labyrinth-map"))
        if button(AccessibilityID.Play.labyrinthEnter).exists {
            tapButton(AccessibilityID.Play.labyrinthEnter)
        }
        tapButton(AccessibilityID.Play.labyrinthFloor1EntryNode)
        assertExists(AccessibilityID.Play.labyrinthNodeInspector)
        let action = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", AccessibilityID.Play.labyrinthInspectorAction(""),
        )).firstMatch
        assertExists(action)
        let selected = action.identifier
        let locked = any(AccessibilityID.Play.labyrinthFloor1LockedNode)
        scrollUntilVisible(locked, swipingUp: true, requireHittable: true)
        XCTAssertFalse(locked.isEnabled)
        locked.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        assertExists(selected)
        tapWhenReady(button(AccessibilityID.Play.labyrinthDismissSelection).firstMatch)
        assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)
        assertExistsAfterScroll(AccessibilityID.Play.labyrinthFloor1EntryNode, requireHittable: true)
        tapButton(AccessibilityID.Play.labyrinthFloor1EntryNode)
        tapButton(selected)
        // The entry is a battle in the unmodified initial map.
        battle.assertActive()
    }
}
