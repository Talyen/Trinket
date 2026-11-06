import TrinketFeatureSupport
import XCTest

final class RewardReturnUITests: TrinketUITestCase {
    func testClaimReturnsToCampaignAndOpensNextStage() throws {
        launchRewardReturnFixture()
        assertExists(AccessibilityID.Battle.victory)
        reveal(button(AccessibilityID.Battle.continueButton))
        try claimRewardAndEnterNextStage()
    }
}
