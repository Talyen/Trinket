import SwiftUI
import XCTest
@testable import Trinket

final class BattleArtViewportLayoutTests: XCTestCase {
    func testWideViewportFillsWidthAndCropsVertically() {
        let placement = BattleArtViewportLayout.placement(
            in: CGSize(width: 400, height: 200),
            focalPoint: .center
        )

        XCTAssertEqual(placement.size.width, 400, accuracy: 0.001)
        XCTAssertEqual(placement.size.height, 533.333, accuracy: 0.001)
        XCTAssertEqual(placement.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(placement.origin.y, -166.667, accuracy: 0.001)
        XCTAssertEqual(placement.center.x, 200, accuracy: 0.001)
        XCTAssertEqual(placement.center.y, 100, accuracy: 0.001)
    }

    func testTallViewportFillsHeightAndCropsHorizontally() {
        let placement = BattleArtViewportLayout.placement(
            in: CGSize(width: 200, height: 400),
            focalPoint: .center
        )

        XCTAssertEqual(placement.size.width, 300, accuracy: 0.001)
        XCTAssertEqual(placement.size.height, 400, accuracy: 0.001)
        XCTAssertEqual(placement.origin.x, -50, accuracy: 0.001)
        XCTAssertEqual(placement.origin.y, 0, accuracy: 0.001)
        XCTAssertEqual(placement.center.x, 100, accuracy: 0.001)
        XCTAssertEqual(placement.center.y, 200, accuracy: 0.001)
    }

    func testFocalCropClampsBeforeShowingEmptySpace() {
        let placement = BattleArtViewportLayout.placement(
            in: CGSize(width: 200, height: 400),
            focalPoint: UnitPoint(x: 0.10, y: 0.50)
        )

        XCTAssertEqual(placement.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(placement.origin.y, 0, accuracy: 0.001)
    }
}
