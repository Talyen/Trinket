import TrinketFeatureSupport
import XCTest

final class AudioLifecycleUITests: TrinketUITestCase {
    func testRealBackendsPlayAfterBattleAndForegroundRouting() throws {
        launchApp(arguments: TestLaunchArg.productionTiming(tab: "options", audio: true)
            + ["-performance-strong-party", "-coverage-diagnostics"])
        let musicVolume = app.sliders["Music"]
        XCTAssertTrue(musicVolume.trinketWaitForExistence(timeout: Self.defaultTimeout))
        trinketOnMainActor {
            XCTAssertEqual(musicVolume.value as? String, "0%")
            // Grab the muted thumb; AX adjustment can leave it at zero, so a subsequent
            // drag from the requested AX position can miss the thumb entirely.
            let start = musicVolume.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5))
            let end = musicVolume.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        waitUntil("Dragging Music must update its displayed volume") {
            trinketOnMainActor { (musicVolume.value as? String).map { $0 != "0%" } ?? false }
        }
        let enabledVolume = try trinketOnMainActor { try XCTUnwrap(musicVolume.value as? String) }
        attachSuccessScreenshot(named: "music-volume-after-native-drag")
        waitUntil("Music must start after enabling simulator music") {
            do { return try (self.coverageReport()["musicStarts"] as? Int ?? 0) > 0 }
            catch { return false }
        }
        tabBar.select(.play)
        play.openExplore()
        tapButtonAfterScroll(AccessibilityID.Play.contractsModeCard)
        var plays = 0
        try completeAudioContract {
            let musicStarts = try XCTUnwrap(coverageReport()["musicStarts"] as? Int)
            backgroundAndActivate()
            // Observe the restart while still in battle: returning to the board
            // starts menu music and could otherwise mask a failed foreground resume.
            waitUntil("Foreground routing must restart battle music") {
                ((try? self.coverageReport())?["musicStarts"] as? Int ?? 0) > musicStarts
            }
            plays = try XCTUnwrap(coverageReport()["sfxPlays"] as? Int)
        }
        var after: [String: Any] = [:]
        waitUntil("The resumed battle must schedule another sound") {
            after = (try? self.coverageReport()) ?? [:]
            return (after["sfxPlays"] as? Int ?? 0) > plays
        }
        XCTAssertEqual(after["audioFailures"] as? Int, 0)
        XCTAssertEqual(after["duplicateMusicOwners"] as? Int, 0)
        let attachment = XCTAttachment(string: String(describing: after))
        attachment.name = "real-backend-observations-not-audibility-proof"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate()
        launchApp(arguments: [TestLaunchArg.disableCloudSync, "-selectedTab", "options", "-coverage-diagnostics"])
        let restoredVolume = app.sliders["Music"]
        XCTAssertTrue(restoredVolume.trinketWaitForExistence(timeout: Self.defaultTimeout))
        trinketOnMainActor {
            XCTAssertEqual(restoredVolume.value as? String, enabledVolume, "Music volume must survive relaunch")
        }
        waitUntil("Persisted Music volume must start playback after relaunch") {
            ((try? self.coverageReport())?["musicStarts"] as? Int ?? 0) > 0
        }
    }
}

extension TrinketUITestCase {
    @discardableResult
    func completeAudioContract(afterEntry: () throws -> Void = {}) throws -> Bool {
        let fight = button(AccessibilityID.Play.contractFight("easy"))
        assertExists(AccessibilityID.Play.contractsBoard)
        // Easy is the first offer; scroll toward the top only when it is clipped.
        XCTAssertTrue(app.scrollUntilVisible(fight, swipingUp: false, requireHittable: true), "The next Contract must be reachable")
        tapWhenReady(fight)
        battle.assertActive()
        try afterEntry()
        tapWhenReady(battle.autoBattleToggle)
        waitUntil("Audio-enabled battle must resolve", timeout: 45) {
            self.any(AccessibilityID.Battle.victory).exists || self.any(AccessibilityID.Battle.defeat).exists
        }
        let won = any(AccessibilityID.Battle.victory).exists
        let leave = won ? AccessibilityID.Battle.continueButton : AccessibilityID.Battle.defeatLeaveButton
        tapButtonAfterScroll(leave)
        dismissEarnedTalentChoicesIfPresented()
        assertExists(AccessibilityID.Play.contractsBoard)
        return won
    }
}
