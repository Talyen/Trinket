import TrinketFeatureSupport
import UIKit
import XCTest

final class DuoRotationUITests: TrinketUITestCase {
    func testDuoRotationPreservesBattleAndCardPlay() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TRINKET_DUO_PROFILE"] == "1", "Requires the Duo coverage profile")
        let device = XCUIDevice.shared
        let originalOrientation = device.orientation
        defer { device.orientation = originalOrientation }

        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval("60", in: TestLaunchArg.allForBattle()))
        battle.assertActive()
        let originalCards = handCardIDs
        XCTAssertFalse(originalCards.isEmpty)

        let window = app.windows.firstMatch
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait, .landscapeRight] {
            device.orientation = orientation
            let resized = trinketWaitUntil(timeout: Self.defaultTimeout) {
                let frame = window.exists ? window.frame : .null
                return frame.width > 0 && frame.height > 0
                    && (orientation.isLandscape ? frame.width > frame.height : frame.height > frame.width)
            }
            let frame = window.exists ? window.frame : .null
            retainScreenshot(named: "duo-window-\(orientation.rawValue)")
            let resizedFrame = try XCTUnwrap(
                resized ? frame : nil,
                "Duo window did not resize: requested=\(orientation.rawValue), device=\(device.orientation.rawValue), window=\(frame)",
            )
            XCTContext.runActivity(named: "Duo window resized: requested=\(orientation.rawValue), window=\(resizedFrame)") { _ in }
            waitUntil("Duo rotation must preserve the hand and usable battle controls") {
                self.handCardIDs == originalCards && self.battle.autoBattleToggle.isHittable && self.battle.actionsMenu.isHittable
            }
        }

        let card = battle.frontmostHandCard
        let playedID = card.identifier
        tapWhenReady(card)
        waitUntil("The rotated battle must still accept card play") { !self.button(playedID).exists }
    }

    private var handCardIDs: Set<String> {
        let cards = battle.handCards
        return trinketOnMainActor {
            Set(cards.allElementsBoundByIndex.map(\.identifier))
        }
    }
}
