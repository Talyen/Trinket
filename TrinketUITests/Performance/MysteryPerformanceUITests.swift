import TrinketFeatureSupport
import XCTest

final class MysteryPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testReward() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allUnseeded()
                    + TestLaunchArg.screen("mystery")
                    + TestLaunchArg.completedStages(["chapter-1-stage-1"])
                    + TestLaunchArg.mysteryRecruit(eventID: "medicinal-herb-garden")))
            assertExists(AccessibilityID.Mystery.encounterTitle)
            assertExistsAfterScroll(AccessibilityID.Mystery.choiceButton(choiceID: "harvest-remedies"), requireHittable: true)
            measured("mystery-reward-reveal", iteration: iteration, settle: 3) {
                tapButton(AccessibilityID.Mystery.choiceButton(choiceID: "harvest-remedies"))
                assertExists(AccessibilityID.Mystery.rewardTitle)
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
            tapButton(AccessibilityID.Mystery.choiceButton(choiceID: "corrupt-item"))
            tapButton(AccessibilityID.Mystery.confirmChoiceButton)
            assertExists(AccessibilityID.Mystery.corruptItemTitle)
            let candidate = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Mystery Corrupt Item ")).firstMatch
            reveal(candidate)
            measured("corruption-reveal", iteration: iteration, settle: 3) {
                tapWhenReady(candidate)
                tapButton(AccessibilityID.Mystery.corruptConfirmButton)
                assertExists(AccessibilityID.Mystery.corruptionRevealTitle)
            }
        }
    }
}
