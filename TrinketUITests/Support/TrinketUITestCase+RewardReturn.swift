import TrinketFeatureSupport
import XCTest

extension TrinketUITestCase {
    func launchRewardReturnFixture() {
        launchApp(arguments: TestLaunchArg.productionTiming()
            + TestLaunchArg.screen("battle-victory") + ["-coverage-diagnostics"])
    }

    func claimRewardAndEnterNextStage() throws {
        tapButton(AccessibilityID.Battle.continueButton)
        play.assertCampaignLoaded()
        let state = try coverageReport()
        let keys = ["selectedTab", "playPath", "pendingPlayDestination", "gameplayActive", "completedStages"]
        let summary = keys.map { key in "\(key)=\(String(describing: state[key]))" }.joined(separator: "\n")
        let attachment = XCTAttachment(string: summary)
        attachment.name = "reward-return-state"
        attachment.lifetime = .keepAlways
        add(attachment)
        tapButtonAfterScroll(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        assertExists(AccessibilityID.Mystery.encounterTitle)
    }
}
