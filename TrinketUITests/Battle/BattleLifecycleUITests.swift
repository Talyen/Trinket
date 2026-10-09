import TrinketContent
import TrinketFeatureSupport
import XCTest

final class BattleLifecycleUITests: TrinketUITestCase {
    func testBackgroundedBattleAcceptsManualPlayAfterReturn() {
        launchApp(arguments: TestLaunchArg.productionTiming())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        battle.assertActive()
        backgroundAndActivate()
        let card = battle.handCards.firstMatch
        assertExists(card)
        let identity = card.identifier
        tapWhenReady(card)
        waitUntil("Returned battle must accept manual input") {
            !self.any(identity).exists || self.any(AccessibilityID.Battle.victory).exists
        }
    }

    func testCommittedRewardSurvivesTerminationWithoutReseeding() {
        launchApp(arguments: TestLaunchArg.allForTab("play")
            + ["-performance-strong-party", TestLaunchArg.rewardCheckpoint])
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        tapWhenReady(battle.autoBattleToggle)
        assertExists(AccessibilityID.Battle.victory, timeout: 30)
        assertExistsAfterScroll(AccessibilityID.Battle.continueButton, requireHittable: true)
        tapButton(AccessibilityID.Battle.continueButton)
        assertExists(AccessibilityID.Debug.rewardCollectionCheckpoint)
        relaunchApp()
        play.openCampaign()
        let next = button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        assertExists(next)
        XCTAssertTrue(next.isEnabled, "Accepted rewards must retain progression after termination")
        tapWhenReady(next)
        assertExists(AccessibilityID.Mystery.continueButton)
    }

    func testDefeatLeaveRetriesFailedWriteAndReturnsToCampaign() {
        launchApp(arguments: TestLaunchArg.allForScreen("battle-defeat-save-failure"))
        assertExists(AccessibilityID.Battle.defeat)
        tapButton(AccessibilityID.Battle.defeatLeaveButton)
        play.assertCampaignLoaded()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        relaunchApp()
        play.openCampaign()
        XCTAssertTrue(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 1)).isEnabled)
    }

    func testBackgroundedTalentConfirmationExposesNextEarnedChoice() throws {
        launchApp(arguments: TestLaunchArg.allForTab("play")
            + ["-coverage-talent-pair", "-hold-talent-confirmation"])
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        battle.openActions()
        tapButton(AccessibilityID.Battle.skipCombat)
        assertExists(AccessibilityID.Battle.victory)
        assertExistsAfterScroll(AccessibilityID.Battle.continueButton, requireHittable: true)
        tapButton(AccessibilityID.Battle.continueButton)
        assertExists(AccessibilityID.TalentChoice.screen)
        let heroTree = try XCTUnwrap(CombatantTalentCatalog.allConfigs["ranger"]?.trees.first)
        let node = try XCTUnwrap(heroTree.nodes.first)
        tapButton(AccessibilityID.TalentChoice.tree(id: heroTree.id))
        tapButton(AccessibilityID.TalentChoice.node(id: node.id))
        tapButton(AccessibilityID.TalentChoice.unlockButton)
        assertExists(AccessibilityID.Debug.talentConfirmationCheckpoint)
        backgroundAndActivate()
        let companionTree = try XCTUnwrap(CombatantTalentCatalog.allConfigs["wolf"]?.trees.first)
        assertExists(AccessibilityID.TalentChoice.tree(id: companionTree.id))
        assertDoesNotExist(AccessibilityID.Debug.talentConfirmationCheckpoint)
    }

    func testProductionTimingRapidCardsAndDragLeaveUsableExit() {
        launchApp(arguments: TestLaunchArg.productionTiming())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        let first = battle.handCards.firstMatch
        assertExists(first)
        let firstID = first.identifier
        first.tap()
        let second = battle.handCards.firstMatch
        assertExists(second)
        let secondID = second.identifier
        second.tap()
        waitUntil("Distinct rapid plays must depart from the hand") {
            !self.any(firstID).exists && !self.any(secondID).exists
        }
        let drag = battle.handCards.firstMatch
        assertExists(drag)
        let dragID = drag.identifier
        let origin = drag.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        origin.press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 0, dy: -240)))
        waitUntil("Drag following rapid casts must still play") { !self.any(dragID).exists }
        battle.openActions()
        tapButton(AccessibilityID.Battle.retreat)
        assertExists(AccessibilityID.Battle.defeat)
        tapButton(AccessibilityID.Battle.defeatLeaveButton)
        play.assertCampaignLoaded()
    }
}
