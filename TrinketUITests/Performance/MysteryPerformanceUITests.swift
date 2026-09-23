import TrinketFeatureSupport
import XCTest

final class MysteryPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testRecruitReveal() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allUnseeded()
                    + TestLaunchArg.completedStages(["chapter-1-stage-1"])
                    + TestLaunchArg.mysteryRecruit(eventID: "recruit-bear")) + ["-performance-mystery-map"])
            play.openCampaign()
            reveal(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2)))
            measured("recruit-map-reveal", iteration: iteration, settle: 3) {
                tapButton(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
                assertExists(AccessibilityID.Mystery.unlockCard(name: "Bear"))
            }
            measured("recruit-map-return", iteration: iteration) {
                reveal(button(AccessibilityID.Mystery.continueButton))
                tapButton(AccessibilityID.Mystery.continueButton)
                assertDoesNotExist(AccessibilityID.Mystery.unlockCard(name: "Bear"))
                play.assertCampaignLoaded()
            }
        }
    }

    @MainActor
    func testReward() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allUnseeded()
                    + TestLaunchArg.screen("mystery")
                    + TestLaunchArg.completedStages(["chapter-1-stage-1"])
                    + TestLaunchArg.mysteryRecruit(eventID: "medicinal-herb-garden")))
            assertExists(AccessibilityID.Mystery.encounterTitle)
            measured("mystery-offer-inspection", iteration: iteration) {
                tapButton(AccessibilityID.Mystery.offerArtwork(choiceID: "harvest-remedies"))
                let inspected = ["chapter-1-stage-2-harvest-remedies", "mortar_and_pestle"].contains {
                    any(AccessibilityID.LoadoutPicker.itemDetail($0)).trinketWaitForExistence(timeout: 3)
                }
                XCTAssertTrue(inspected)
                dismissSheet()
                assertExists(AccessibilityID.Mystery.encounterTitle)
            }
            assertExistsAfterScroll(AccessibilityID.Mystery.choiceButton(choiceID: "harvest-remedies"), requireHittable: true)
            measured("mystery-reward-reveal", iteration: iteration, settle: 3) {
                tapButton(AccessibilityID.Mystery.choiceButton(choiceID: "harvest-remedies"))
                assertExists(AccessibilityID.Mystery.rewardTitle)
            }
            measured("mystery-reward-claim", iteration: iteration) {
                assertExistsAfterScroll(AccessibilityID.Mystery.continueButton, requireHittable: true)
                tapButton(AccessibilityID.Mystery.continueButton)
                assertDoesNotExist(AccessibilityID.Mystery.rewardTitle)
                play.assertLoaded()
            }
        }
    }

    @MainActor
    func testRecruitReturn() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allUnseeded()
                    + TestLaunchArg.screen("mystery")
                    + TestLaunchArg.completedStages(["chapter-1-stage-1"])
                    + TestLaunchArg.mysteryRecruit(eventID: "recruit-bear")))
            assertExists(AccessibilityID.Mystery.unlockCard(name: "Bear"))
            measured("recruit-claim-return", iteration: iteration) {
                assertExistsAfterScroll(AccessibilityID.Mystery.continueButton, requireHittable: true)
                tapButton(AccessibilityID.Mystery.continueButton)
                assertDoesNotExist(AccessibilityID.Mystery.unlockCard(name: "Bear"))
                play.assertLoaded()
            }
        }
    }

    @MainActor
    func testCorruption() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allForScreen("mystery")
                    + TestLaunchArg.completedStages(["chapter-1-stage-1"])
                    + TestLaunchArg.mysteryRecruit(eventID: "corruption-altar")))
            assertExists(AccessibilityID.Mystery.encounterTitle)
            assertExistsAfterScroll(AccessibilityID.Mystery.choiceButton(choiceID: "corrupt-item"), requireHittable: true)
            measured("corruption-item-picker", iteration: iteration) {
                tapButton(AccessibilityID.Mystery.choiceButton(choiceID: "corrupt-item"))
                tapButton(AccessibilityID.Mystery.confirmChoiceButton)
                assertExists(AccessibilityID.Mystery.corruptItemTitle)
            }
            let corruptPickerProbes = captureScrollProbes(app.scrollViews.firstMatch)
            let didScroll = measured("corruption-item-scroll", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch)
            }
            if didScroll {
                verifyScrollProbes(corruptPickerProbes, app.scrollViews.firstMatch)
            }
            let candidate = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Mystery Corrupt Item ")).firstMatch
            reveal(candidate)
            measured("corruption-reveal", iteration: iteration, settle: 3) {
                tapWhenReady(candidate)
                tapButton(AccessibilityID.Mystery.corruptConfirmButton)
                assertExists(AccessibilityID.Mystery.corruptionRevealTitle)
            }
            measured("corruption-return", iteration: iteration) {
                assertExistsAfterScroll(AccessibilityID.Mystery.corruptionContinueButton, requireHittable: true)
                tapButton(AccessibilityID.Mystery.corruptionContinueButton)
                play.assertLoaded()
            }
        }
    }
}
