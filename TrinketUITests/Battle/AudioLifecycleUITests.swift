import TrinketFeatureSupport
import XCTest

final class AudioLifecycleUITests: TrinketUITestCase {
    func testRealBackendsPlayAfterBattleAndForegroundRouting() throws {
        launchApp(arguments: TestLaunchArg.productionTiming(audio: true)
            + ["-performance-strong-party", "-coverage-diagnostics"])
        play.openExplore()
        tapButton(AccessibilityID.Play.contractsModeCard)
        completeAudioContract()
        let before = try coverageReport()
        backgroundAndActivate()
        completeAudioContract()
        try waitForAudioProgress(after: XCTUnwrap(before["sfxPlays"] as? Int))
        let musicStarts = try XCTUnwrap(before["musicStarts"] as? Int)
        waitUntil("Foreground routing must restart real music playback") {
            do { return try (self.coverageReport()["musicStarts"] as? Int ?? 0) > musicStarts }
            catch { return false }
        }
        let after = try coverageReport()
        XCTAssertGreaterThan(try XCTUnwrap(after["sfxPlays"] as? Int), try XCTUnwrap(before["sfxPlays"] as? Int))
        XCTAssertGreaterThan(try XCTUnwrap(after["musicStarts"] as? Int), try XCTUnwrap(before["musicStarts"] as? Int))
        XCTAssertEqual(after["audioFailures"] as? Int, 0)
        XCTAssertEqual(after["duplicateMusicOwners"] as? Int, 0)
        let attachment = XCTAttachment(string: String(describing: after))
        attachment.name = "real-backend-observations-not-audibility-proof"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func completeAudioContract() {
        assertExists(AccessibilityID.Play.contractsBoard)
        tapButton(AccessibilityID.Play.contractFight("easy"))
        battle.assertActive()
        tapWhenReady(battle.autoBattleToggle)
        waitUntil("Audio-enabled battle must resolve", timeout: 45) {
            self.any(AccessibilityID.Battle.victory).exists || self.any(AccessibilityID.Battle.defeat).exists
        }
        let leave = any(AccessibilityID.Battle.victory).exists
            ? AccessibilityID.Battle.continueButton : AccessibilityID.Battle.defeatLeaveButton
        assertExistsAfterScroll(leave, requireHittable: true)
        tapButton(leave)
        dismissEarnedTalentChoicesIfPresented()
        assertExists(AccessibilityID.Play.contractsBoard)
    }
}
