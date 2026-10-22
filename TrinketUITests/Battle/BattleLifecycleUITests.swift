import TrinketContent
import TrinketFeatureSupport
import XCTest

final class BattleLifecycleUITests: TrinketUITestCase {
    func testCommittedRewardSurvivesTerminationWithoutReseeding() throws {
        launchApp(arguments: TestLaunchArg.allForScreen("battle-victory")
            + [TestLaunchArg.rewardCheckpoint, "-coverage-diagnostics"])
        let goldBefore = try XCTUnwrap(coverageReport()["gold"] as? Int)
        assertExists(AccessibilityID.Battle.victory)
        assertExistsAfterScroll(AccessibilityID.Battle.continueButton, requireHittable: true)
        tapButton(AccessibilityID.Battle.continueButton)
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

    func testBackgroundedProductionBattleAcceptsRapidCardsDragAndExit() {
        launchApp(arguments: TestLaunchArg.productionTiming())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        battle.assertActive()
        backgroundAndActivate()
        let first = battle.frontmostHandCard
        assertExists(first)
        let firstID = first.identifier
        tapWhenReady(first)
        let second = battle.frontmostHandCard
        assertExists(second)
        let secondID = second.identifier
        tapWhenReady(second)
        waitUntil("Distinct rapid plays must depart from the hand") {
            !self.any(firstID).exists && !self.any(secondID).exists
        }
        let drag = battle.frontmostHandCard
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
