import XCTest
@testable import Trinket

final class TapTargetGameTests: XCTestCase {
    func testResetCentersTargetAndClearsScore() {
        var game = TapTargetGame()

        game.hitTarget(in: CGSize(width: 300, height: 400))
        game.reset(in: CGSize(width: 300, height: 400))

        XCTAssertEqual(game.score, 0)
        XCTAssertEqual(game.targetPosition.x, 150)
        XCTAssertEqual(game.targetPosition.y, 200)
    }

    func testHitIncrementsScore() {
        var game = TapTargetGame()

        game.hitTarget(in: CGSize(width: 300, height: 400))
        game.hitTarget(in: CGSize(width: 300, height: 400))

        XCTAssertEqual(game.score, 2)
    }
}
