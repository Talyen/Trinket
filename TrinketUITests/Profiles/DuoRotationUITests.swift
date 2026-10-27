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

        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait, .landscapeRight] {
            device.orientation = orientation
            let settled = trinketWaitUntil(timeout: Self.defaultTimeout) {
                let frame = self.app.frame
                let resized = orientation.isLandscape ? frame.width > frame.height : frame.height > frame.width
                return resized && self.handCardIDs == originalCards
                    && self.battle.autoBattleToggle.isHittable && self.battle.actionsMenu.isHittable
            }
            if !settled {
                retainScreenshot(named: "duo-rotation-failure-\(orientation.rawValue)")
                let frame = app.frame
                XCTFail(
                    "Rotation must preserve the hand and usable battle controls: "
                        + "orientation=\(orientation.rawValue), frame=\(frame), "
                        + "hand=\(handCardIDs.sorted()), originalHand=\(originalCards.sorted()), "
                        + "auto=\(battle.autoBattleToggle.isHittable), actions=\(battle.actionsMenu.isHittable)",
                )
            }
            retainScreenshot(named: "duo-battle-\(orientation.rawValue)")
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
