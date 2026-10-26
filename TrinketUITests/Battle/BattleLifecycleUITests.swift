import TrinketContent
import TrinketFeatureSupport
import XCTest

final class BattleLifecycleUITests: TrinketUITestCase {
    func testCommittedRewardSurvivesTerminationWithoutReseeding() throws {
        launchApp(arguments: TestLaunchArg.allForScreen("battle-victory")
            + [TestLaunchArg.rewardCheckpoint, "-coverage-diagnostics"])
        let goldBefore = try XCTUnwrap(coverageReport()["gold"] as? Int)
        assertExists(AccessibilityID.Battle.victory)
        tapButtonAfterScroll(AccessibilityID.Battle.continueButton)
        assertExists(AccessibilityID.Debug.rewardCollectionCheckpoint)
        waitUntil("The committed claim must credit its Gold before termination") {
            ((try? self.coverageReport())?["gold"] as? Int ?? goldBefore) > goldBefore
        }
        let claimedGold = try XCTUnwrap(coverageReport()["gold"] as? Int)
        relaunchApp(arguments: ["-coverage-diagnostics"])
        play.assertLoaded()
        XCTAssertEqual(try coverageReport()["gold"] as? Int, claimedGold, "Claimed Gold must survive process termination")
        play.openCampaign()
        let next = button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        assertExists(next)
        XCTAssertTrue(next.isEnabled, "Accepted rewards must retain progression after termination")
        tapWhenReady(next)
        assertExists(AccessibilityID.Mystery.encounterTitle)
    }

    func testDefeatLeaveRetriesFailedWriteAndReturnsToCampaign() {
        launchApp(arguments: TestLaunchArg.allForScreen("battle-defeat-save-failure"))
        assertExists(AccessibilityID.Battle.defeat)
        tapButton(AccessibilityID.Battle.defeatLeaveButton)
        play.assertCampaignLoaded()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        play.startBattle(chapter: 1, stage: 1)
        battle.assertActive()
    }

    func testBackgroundedTalentConfirmationsFinishAndLeaveTheNextStagePlayable() throws {
        launchApp(arguments: TestLaunchArg.allForTab("play")
            + ["-coverage-talent-pair", "-hold-talent-confirmation"])
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        battle.openActions()
        tapButton(AccessibilityID.Battle.skipCombat)
        assertExists(AccessibilityID.Battle.victory)
        tapButtonAfterScroll(AccessibilityID.Battle.continueButton)
        assertExists(AccessibilityID.TalentChoice.screen)
        for combatantID in ["ranger", "wolf"] {
            let tree = try XCTUnwrap(CombatantTalentCatalog.allConfigs[combatantID]?.trees.first)
            let node = try XCTUnwrap(tree.nodes.first)
            tapButton(AccessibilityID.TalentChoice.tree(id: tree.id))
            tapButton(AccessibilityID.TalentChoice.node(id: node.id))
            tapButton(AccessibilityID.TalentChoice.unlockButton)
            assertExists(AccessibilityID.Debug.talentConfirmationCheckpoint)
            backgroundAndActivate()
            assertDoesNotExist(AccessibilityID.Debug.talentConfirmationCheckpoint)
        }
        play.assertCampaignLoaded()
        tapButton(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        assertExists(AccessibilityID.Mystery.encounterTitle)
    }
}
