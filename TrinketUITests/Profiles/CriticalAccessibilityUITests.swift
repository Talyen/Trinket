import TrinketFeatureSupport
import XCTest

final class CriticalAccessibilityUITests: FullGameStoreKitUITestCase {
    func testCriticalControlsWithRequestedAccessibilityEnvironment() throws {
        try skipUnavailablePurchaseAutomation()
        try startStoreSession()
        var args = TestLaunchArg.productionTiming() + ["-coverage-diagnostics"]
        let large = ProcessInfo.processInfo.environment["TRINKET_PROFILE_LARGE_TEXT"] == "1"
        let reduced = ProcessInfo.processInfo.environment["TRINKET_PROFILE_REDUCE_MOTION"] == "1"
        if reduced {
            args.append("-coverage-reduce-motion")
        }
        launchApp(arguments: args)
        let probe = any(AccessibilityID.Debug.coverageDiagnostics)
        assertExists(probe)
        let environment = try coverageReport()
        XCTAssertEqual(environment["largeText"] as? Bool, large, "Native text-size setting did not reach SwiftUI")
        XCTAssertEqual(environment["largestText"] as? Bool, large)
        XCTAssertEqual(environment["reduceMotion"] as? Bool, reduced)
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        let card = battle.handCards.firstMatch
        assertExists(card)
        card.press(forDuration: 0.7)
        assertExists(AccessibilityID.Battle.abilityDetail)
        try auditProductAccessibility()
        retainScreenshot(named: "card-inspection")
        dismissSheet(AccessibilityID.Battle.abilityDetail)
        tapWhenReady(battle.handCards.firstMatch)
        battle.openActions()
        tapButton(AccessibilityID.Battle.retreat)
        assertExists(AccessibilityID.Battle.defeat)
        try auditProductAccessibility()
        retainScreenshot(named: "defeat-leave")
        tapButton(AccessibilityID.Battle.defeatLeaveButton)
        play.assertCampaignLoaded()
        tabBar.selectHomestead()
        try verifyWheatFieldUpgrade(relaunch: false, audit: true)
        tapButton(AccessibilityID.Homestead.backButton)
        tabBar.selectOptions()
        assertExistsAfterScroll(AccessibilityID.FullGame.restore, requireHittable: true)
        tapButton(AccessibilityID.FullGame.restore)
        waitUntil("Restore must leave a usable control") { self.button(AccessibilityID.FullGame.restore).isEnabled }
        tapButton(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
        try auditProductAccessibility()
        retainScreenshot(named: "purchase-entry")
        tapButton(AccessibilityID.FullGame.close)
    }

    func testRewardClaimRemainsReachableAndReturnsUnderRequestedSettings() throws {
        var args = TestLaunchArg.productionTiming() + ["-performance-strong-party"]
        if ProcessInfo.processInfo.environment["TRINKET_PROFILE_REDUCE_MOTION"] == "1" {
            args.append("-coverage-reduce-motion")
        }
        launchApp(arguments: args)
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        tapWhenReady(battle.autoBattleToggle)
        assertExists(AccessibilityID.Battle.victory, timeout: 30)
        assertExistsAfterScroll(AccessibilityID.Battle.continueButton, requireHittable: true)
        try auditProductAccessibility()
        retainScreenshot(named: "reward-claim")
        tapButton(AccessibilityID.Battle.continueButton)
        play.assertCampaignLoaded()
        XCTAssertTrue(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2)).isEnabled)
    }
}
