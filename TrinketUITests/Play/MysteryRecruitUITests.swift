import TrinketFeatureSupport
import XCTest

final class MysteryRecruitUITests: TrinketUITestCase {
    func testPortraitOfferInspectionDoesNotClaimAndChoiceOpensReward() {
        launchApp(arguments: TestLaunchArg.allUnseeded()
            + TestLaunchArg.screen("mystery")
            + TestLaunchArg.completedStages(["chapter-1-stage-1"])
            + TestLaunchArg.mysteryRecruit(eventID: "medicinal-herb-garden"))

        assertExists(AccessibilityID.Mystery.encounterTitle)
        assertExists(AccessibilityID.Mystery.offerArtwork(choiceID: "harvest-remedies"))
        assertExists(AccessibilityID.Mystery.offerArtwork(choiceID: "take-the-notes"))
        assertDoesNotExist(AccessibilityID.Mystery.confirmChoiceButton)
        tapButton(AccessibilityID.Mystery.offerArtwork(choiceID: "harvest-remedies"))
        assertDoesNotExist(AccessibilityID.Mystery.rewardTitle)
        dismissSheet()
        assertExistsAfterScroll(AccessibilityID.Mystery.choiceButton(choiceID: "harvest-remedies"), requireHittable: true)
        tapButton(AccessibilityID.Mystery.choiceButton(choiceID: "harvest-remedies"))
        assertExists(AccessibilityID.Mystery.rewardTitle)
        assertExistsAfterScroll(AccessibilityID.Mystery.continueButton, requireHittable: true)
        tapButton(AccessibilityID.Mystery.continueButton)
        assertDoesNotExist(AccessibilityID.Mystery.rewardTitle)
    }

    func testCompanionRecruitContinueReturnsToCampaign() {
        launchApp(arguments: TestLaunchArg.allUnseeded()
            + ["-battle-tick-interval", "1.0"]
            + TestLaunchArg.screen("mystery")
            + TestLaunchArg.completedStages(["chapter-1-stage-1"])
            + TestLaunchArg.mysteryRecruit(eventID: "recruit-bear"))

        assertExists(AccessibilityID.Mystery.unlockCard(name: "Bear"))
        assertExistsAfterScroll(AccessibilityID.Mystery.continueButton, requireHittable: true)
        tapButton(AccessibilityID.Mystery.continueButton)
        assertDoesNotExist(AccessibilityID.Mystery.unlockCard(name: "Bear"), timeout: 8)
        play.openCampaign()
        assertExists(AccessibilityID.Play.stageRow(chapter: 1, stage: 3))
    }
}
