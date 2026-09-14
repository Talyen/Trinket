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
        assertDoesNotExist(AccessibilityID.Mystery.confirmChoiceButton, timeout: 2)
        tapButton(AccessibilityID.Mystery.offerArtwork(choiceID: "harvest-remedies"))
        let inspectedItemIDs = [
            AccessibilityID.LoadoutPicker.itemDetail("chapter-1-stage-2-harvest-remedies"),
            AccessibilityID.LoadoutPicker.itemDetail("mortar_and_pestle"),
        ]
        let inspected = inspectedItemIDs.contains {
            app.descendants(matching: .any)[$0].trinketWaitForExistence(timeout: 3)
        }
        if !inspected {
            fail("Inspected mystery item detail not found")
        }
        dismissSheet()
        assertDoesNotExist(AccessibilityID.Mystery.rewardTitle, timeout: 2)
        assertExistsAfterScroll(AccessibilityID.Mystery.choiceButton(choiceID: "harvest-remedies"), requireHittable: true)
        tapButton(AccessibilityID.Mystery.choiceButton(choiceID: "harvest-remedies"))
        assertExists(AccessibilityID.Mystery.rewardTitle)
        assertExistsAfterScroll(AccessibilityID.Mystery.continueButton, requireHittable: true)
        tapButton(AccessibilityID.Mystery.continueButton)
        assertDoesNotExist(AccessibilityID.Mystery.rewardTitle, timeout: 5)
        play.assertLoaded()
    }

    func testCompanionRecruitContinueReturnsToPlay() {
        launchApp(arguments: TestLaunchArg.allUnseeded()
            + TestLaunchArg.screen("mystery")
            + TestLaunchArg.completedStages(["chapter-1-stage-1"])
            + TestLaunchArg.mysteryRecruit(eventID: "recruit-bear"))

        assertExists(AccessibilityID.Mystery.unlockCard(name: "Bear"))
        assertExistsAfterScroll(AccessibilityID.Mystery.continueButton, requireHittable: true)
        tapButton(AccessibilityID.Mystery.continueButton)
        assertDoesNotExist(AccessibilityID.Mystery.unlockCard(name: "Bear"), timeout: 5)
        play.assertLoaded()
    }
}
