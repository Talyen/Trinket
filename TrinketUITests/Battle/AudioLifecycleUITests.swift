import TrinketFeatureSupport
import XCTest

final class AudioLifecycleUITests: TrinketUITestCase {
    func testRealBackendsPlayAfterBattleAndForegroundRouting() throws {
        launchApp(arguments: TestLaunchArg.productionTiming(tab: "options", audio: true)
            + ["-performance-strong-party", "-coverage-diagnostics"])
        options.assertLoaded()
        let musicVolume = app.sliders["Music"]
        XCTAssertTrue(musicVolume.trinketWaitForExistence(timeout: Self.defaultTimeout))
        musicVolume.adjust(toNormalizedSliderPosition: 0.75)
        waitUntil("Music must start after enabling simulator music") {
            do { return try (self.coverageReport()["musicStarts"] as? Int ?? 0) > 0 }
            catch { return false }
        }
        tabBar.selectPlay()
        play.openExplore()
        tapButton(AccessibilityID.Play.contractsModeCard)
        completeAudioContract()
        let before = try coverageReport()
        backgroundAndActivate()
        completeAudioContract()
        let plays = try XCTUnwrap(before["sfxPlays"] as? Int)
        let musicStarts = try XCTUnwrap(before["musicStarts"] as? Int)
        var after: [String: Any] = [:]
        waitUntil("Foreground routing must restart music and schedule another sound") {
            after = (try? self.coverageReport()) ?? [:]
            return (after["sfxPlays"] as? Int ?? 0) > plays
                && (after["musicStarts"] as? Int ?? 0) > musicStarts
        }
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
