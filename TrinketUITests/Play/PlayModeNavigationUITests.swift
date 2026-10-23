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

    func testLabyrinthBossContinueOpensAUsableNextFloor() throws {
        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval("0.01", in: TestLaunchArg.allForTab("play"))
            + ["-performance-labyrinth-node", "boss", "-performance-strong-party"])
        play.openExplore()
        assertExistsAfterScroll(AccessibilityID.Play.labyrinthModeCard, requireHittable: true)
        tapButton(AccessibilityID.Play.labyrinthModeCard)
        if button(AccessibilityID.Play.labyrinthEnter).exists {
            tapButton(AccessibilityID.Play.labyrinthEnter)
        }
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
        assertExists(AccessibilityID.Battle.victory, timeout: 60)
        assertExistsAfterScroll(AccessibilityID.Battle.continueButton, requireHittable: true)
        tapButton(AccessibilityID.Battle.continueButton)
        assertExists(AccessibilityID.Play.labyrinthMap)
        let floorMenu = button(AccessibilityID.Play.labyrinthFloorMenu)
        // Switch away first: Continue can already select floor 2 automatically.
        tapWhenReady(floorMenu)
        tapButton(AccessibilityID.Play.labyrinthFloor(1))
        XCTAssertEqual(try integer(in: floorMenu), 1)
        tapWhenReady(floorMenu)
        tapButton(AccessibilityID.Play.labyrinthFloor(2))
        XCTAssertEqual(try integer(in: floorMenu), 2, "The floor picker must change the displayed floor")
        assertExists(AccessibilityID.Play.labyrinthMap)
    }

    func testVoyageEmbarkAndAbandonStayAbandonedAfterRelaunch() {
        launchApp(arguments: TestLaunchArg.allForTab("play"))
        play.openExplore()
        assertExistsAfterScroll(AccessibilityID.Voyage.modeCard, requireHittable: true)
        tapButton(AccessibilityID.Voyage.modeCard)
        assertExists(AccessibilityID.Voyage.screen)
        let embark = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", AccessibilityID.Voyage.action(""),
        )).firstMatch
        tapWhenReady(embark)
        tapButton(AccessibilityID.Voyage.options)
        tapButton(AccessibilityID.Voyage.abandon)
        tapButton(AccessibilityID.Voyage.confirmAbandon)
        assertExists(AccessibilityID.Voyage.refresh)
        assertDoesNotExist(AccessibilityID.Voyage.options)
        relaunchApp()
        play.openExplore()
        assertExistsAfterScroll(AccessibilityID.Voyage.modeCard, requireHittable: true)
        tapButton(AccessibilityID.Voyage.modeCard)
        assertExists(AccessibilityID.Voyage.refresh)
        assertDoesNotExist(AccessibilityID.Voyage.options)
    }

    func testSpireWithoutMatchingPartyKeywordsPreservesFloorLocksAndLaunch() {
        launchApp(arguments: TestLaunchArg.allForTab("play"))
        play.openExplore()
        tapButton(AccessibilityID.Play.spiresModeCard)
        assertExistsAfterScroll(AccessibilityID.Play.spireRow("cinderSpire"), requireHittable: true)
        tapButton(AccessibilityID.Play.spireRow("cinderSpire"))
        assertExists(AccessibilityID.Play.spireClimb("cinderSpire"))
        let locked = any(AccessibilityID.Play.spireFloor("cinderSpire", floor: 2)).firstMatch
        scrollUntilVisible(locked, swipingUp: true, requireHittable: true)
        locked.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        assertDoesNotExist(AccessibilityID.Battle.hand)
        XCTAssertFalse(button(AccessibilityID.Play.spireBeginFloor("cinderSpire", floor: 2)).exists)
        let begin = button(AccessibilityID.Play.spireBeginFloor("cinderSpire", floor: 1))
        scrollUntilVisible(begin, swipingUp: false, requireHittable: true)
        tapWhenReady(begin)
        battle.assertActive()
    }

    func testLabyrinthLockedTapPreservesSelectionAndBackgroundDismissesInspector() {
        launchApp(arguments: TestLaunchArg.allForScreen("labyrinth-map"))
        if button(AccessibilityID.Play.labyrinthEnter).exists {
            tapButton(AccessibilityID.Play.labyrinthEnter)
        }
        tapWhenReady(any(AccessibilityID.Play.labyrinthFloor1EntryNode))
        assertExists(AccessibilityID.Play.labyrinthNodeInspector)
        let action = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", AccessibilityID.Play.labyrinthInspectorAction(""),
        )).firstMatch
        assertExists(action)
        let selected = action.identifier
        let locked = any(AccessibilityID.Play.labyrinthFloor1LockedNode)
        scrollUntilVisible(locked, swipingUp: true, requireHittable: true)
        let label = locked.label
        XCTAssertTrue(label.hasSuffix(", locked"), label)
        locked.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        assertExists(selected)
        let entry = any(AccessibilityID.Play.labyrinthFloor1EntryNode)
        scrollUntilVisible(entry, swipingUp: false, requireHittable: true)
        // Tap the map background beside a visible node, outside its seal.
        entry.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: -12, dy: 0)).tap()
        assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)
        assertExistsAfterScroll(AccessibilityID.Play.labyrinthFloor1EntryNode, requireHittable: true)
        tapWhenReady(any(AccessibilityID.Play.labyrinthFloor1EntryNode))
        tapButton(selected)
        // The entry is a battle in the unmodified initial map.
        battle.assertActive()
    }
}
