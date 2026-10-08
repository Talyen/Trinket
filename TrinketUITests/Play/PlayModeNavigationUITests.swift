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
}
