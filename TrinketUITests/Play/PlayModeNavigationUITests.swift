import TrinketFeatureSupport
import XCTest

final class PlayModeNavigationUITests: TrinketUITestCase {
    func testVoyageEmbarkAndAbandonReturnToAvailableDestinations() {
        launchApp(arguments: TestLaunchArg.allUnseeded())
        play.openExplore()
        let mode = app.buttons[AccessibilityID.Voyage.modeCard]
        scrollUntilVisible(mode, swipingUp: true, maxAttempts: 4, requireHittable: true)
        tapWhenReady(mode)
        assertExists(AccessibilityID.Voyage.screen)
        let embark = app.buttons[AccessibilityID.Voyage.action("easy")]
        scrollUntilVisible(embark, swipingUp: true, maxAttempts: 3, requireHittable: true)
        tapWhenReady(embark)
        assertExists(AccessibilityID.Voyage.destinationReward)
        XCTAssertFalse(app.buttons[AccessibilityID.Voyage.refresh].exists)
        tapWhenReady(app.buttons[AccessibilityID.Voyage.options])
        tapWhenReady(app.buttons[AccessibilityID.Voyage.abandon])
        XCTAssertFalse(app.alerts.firstMatch.exists)
        tapWhenReady(app.buttons[AccessibilityID.Voyage.confirmAbandon])
        assertExists(AccessibilityID.Voyage.action("easy"))
        assertExists(AccessibilityID.Voyage.refresh)
    }

    func testLabyrinthMapNodeInspectorInteractions() {
        launchApp(arguments: TestLaunchArg.allForScreen("labyrinth-map"))

        let enterButton = app.descendants(matching: .any)[AccessibilityID.Play.labyrinthEnter]
        if enterButton.trinketWaitForExistence(timeout: 3) {
            tapWhenReady(enterButton)
        }
        assertExists(AccessibilityID.Play.labyrinthMap, timeout: 20)
        let entryNode = any(AccessibilityID.Play.labyrinthFloor1EntryNode)
        assertExists(entryNode)
        tapWhenReady(entryNode)
        assertExists(AccessibilityID.Play.labyrinthNodeInspector, timeout: 15)
        let inspectorAction = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Play.labyrinthInspectorAction("")),
        ).firstMatch
        assertExists(inspectorAction, timeout: 10)
        let selectedActionID = inspectorAction.identifier

        let lockedNode = app.descendants(matching: .any)[AccessibilityID.Play.labyrinthFloor1LockedNode].firstMatch
        assertExists(lockedNode)
        // Guard the premise before checking that a locked seal leaves the
        // current selection intact. XCUITest reports this SwiftUI node as
        // enabled even while its action is disabled.
        XCTAssertTrue(lockedNode.label.contains(", locked"), "Expected a locked labyrinth node")
        lockedNode.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        assertExists(selectedActionID, timeout: 10)

        // Dismissal belongs to the background dismiss control, not to node taps.
        app.descendants(matching: .any)[AccessibilityID.Play.labyrinthDismissSelection]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05))
            .tap()
        assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)
    }

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
        let action = app.buttons
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
}
