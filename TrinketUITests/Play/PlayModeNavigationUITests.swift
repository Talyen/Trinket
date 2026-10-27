import TrinketFeatureSupport
import XCTest

final class PlayModeNavigationUITests: TrinketUITestCase {
    func testRecruitContinueMakesTheCompanionAndNextBattleUsable() {
        launchApp(arguments: TestLaunchArg.allUnseeded()
            + TestLaunchArg.completedStages(["chapter-1-stage-1"])
            + TestLaunchArg.mysteryRecruit(eventID: "recruit-bear") + ["-performance-mystery-map"])
        play.openCampaign()
        tapButton(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        assertExists(AccessibilityID.Mystery.unlockCard(name: "Bear"))
        tapButtonAfterScroll(AccessibilityID.Mystery.continueButton)
        play.assertCampaignLoaded()
        tabBar.select(.collection)
        tapButtonAfterScroll(AccessibilityID.CombatantDetail.collectionCard(name: "Bear"))
        combatantDetail.assertLoaded(for: "Bear")
        dismissSheet(AccessibilityID.CombatantDetail.header(name: "Bear"))
        tabBar.select(.play)
        play.startBattle(chapter: 1, stage: 3)
        battle.assertActive()
    }

    func testLabyrinthBossContinueOpensAUsableNextFloor() throws {
        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval("0.01", in: TestLaunchArg.allForTab("play"))
            + ["-performance-labyrinth-node", "boss", "-performance-strong-party"])
        play.openExplore()
        tapButtonAfterScroll(AccessibilityID.Play.labyrinthModeCard)
        if button(AccessibilityID.Play.labyrinthEnter).exists {
            tapButton(AccessibilityID.Play.labyrinthEnter)
        }
        assertExists(AccessibilityID.Play.labyrinthMap)
        let boss = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@",
            AccessibilityID.Play.labyrinthNode(""), "Boss",
        )).firstMatch
        reveal(boss)
        tapWhenReady(boss)
        let action = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Play.labyrinthInspectorAction(""))).firstMatch
        tapWhenReady(action)
        battle.autoBattleToggle.trinketTapWhenReady(timeout: Self.deepLinkTimeout)
        assertExists(AccessibilityID.Battle.victory, timeout: 60)
        tapButtonAfterScroll(AccessibilityID.Battle.continueButton)
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

    func testVoyageEmbarkAndAbandonReturnsToOffers() {
        launchApp(arguments: TestLaunchArg.allForTab("play"))
        play.openExplore()
        tapButtonAfterScroll(AccessibilityID.Voyage.modeCard)
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
    }

    func testLockedSpireFloorStaysInertAndUnlockedFloorStartsBattle() {
        launchApp(arguments: TestLaunchArg.allForTab("play"))
        play.openExplore()
        tapButton(AccessibilityID.Play.spiresModeCard)
        tapButtonAfterScroll(AccessibilityID.Play.spireRow("cinderSpire"))
        assertExists(AccessibilityID.Play.spireClimb("cinderSpire"))
        let locked = any(AccessibilityID.Play.spireFloor("cinderSpire", floor: 2)).firstMatch
        reveal(locked)
        locked.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertFalse(button(AccessibilityID.Play.spireBeginFloor("cinderSpire", floor: 2)).exists)
        let begin = button(AccessibilityID.Play.spireBeginFloor("cinderSpire", floor: 1))
        XCTAssertTrue(app.scrollUntilVisible(begin, swipingUp: false, requireHittable: true), "The unlocked floor must be reachable")
        tapWhenReady(begin)
        battle.assertActive()
    }

    func testLabyrinthLockedTapPreservesSelectionAndBackgroundDismissesInspector() {
        launchApp(arguments: TestLaunchArg.allForScreen("labyrinth-map") + ["-coverage-diagnostics"])
        if button(AccessibilityID.Play.labyrinthEnter).exists {
            tapButton(AccessibilityID.Play.labyrinthEnter)
        }
        let entryNode = any(AccessibilityID.Play.labyrinthFloor1EntryNode)
        let hasEntry = entryNode.trinketWaitForExistence(timeout: Self.defaultTimeout)
        XCTAssertTrue(hasEntry, "Labyrinth entry must appear; diagnostics: \((try? coverageReport()) ?? [:])")
        tapWhenReady(entryNode)
        assertExists(AccessibilityID.Play.labyrinthNodeInspector)
        let action = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", AccessibilityID.Play.labyrinthInspectorAction(""),
        )).firstMatch
        assertExists(action)
        let selected = action.identifier
        let locked = any(AccessibilityID.Play.labyrinthFloor1LockedNode)
        reveal(locked)
        locked.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        assertExists(selected)
        let entry = any(AccessibilityID.Play.labyrinthFloor1EntryNode)
        XCTAssertTrue(app.scrollUntilVisible(entry, swipingUp: false, requireHittable: true), "The entry node must be reachable")
        // Tap the map background beside a visible node, outside its seal.
        entry.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: -12, dy: 0)).tap()
        assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)
        reveal(entry)
        tapWhenReady(entry)
        tapButton(selected)
        // The entry is a battle in the unmodified initial map.
        battle.assertActive()
    }
}
