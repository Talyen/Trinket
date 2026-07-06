import XCTest
@testable import Trinket

final class HeroHeaderLayoutTests: XCTestCase {
    // MARK: - Header height (3:4 of width, minimum 300)

    func testHeaderHeightMatchesThreeToFourAspect() {
        let width: CGFloat = 390
        let height = HeroHeaderLayout.headerHeight(forWidth: width)
        let aspect = height / width
        XCTAssertEqual(aspect, 4.0 / 3.0, accuracy: 0.001)
    }

    func testHeaderHeightHasMinimumOf300() {
        let width: CGFloat = 100
        let height = HeroHeaderLayout.headerHeight(forWidth: width)
        XCTAssertEqual(height, 300)
    }

    func testHeaderHeightAtMinimumThreshold() {
        let width: CGFloat = 225
        let height = HeroHeaderLayout.headerHeight(forWidth: width)
        XCTAssertEqual(height, 300)
    }

    func testHeaderHeightAboveMinimumUsesWidth() {
        let width: CGFloat = 300
        let height = HeroHeaderLayout.headerHeight(forWidth: width)
        XCTAssertEqual(height, 400, accuracy: 0.5)
    }

    func testHeaderHeightForCommonDeviceWidths() {
        let widths: [(CGFloat, CGFloat)] = [
            (320, 427),
            (375, 500),
            (390, 520),
            (414, 552),
            (428, 571)
        ]
        for (width, expected) in widths {
            let height = HeroHeaderLayout.headerHeight(forWidth: width)
            XCTAssertEqual(height, expected, accuracy: 1,
                           "Expected height for width \(width)")
        }
    }

    // MARK: - Overscroll stretch contract

    func testOverscrollIsZeroWhenContentIsNotPulledPastTop() {
        let overscroll = HeroHeaderLayout.overscroll(contentOffsetY: 20, topInset: 0)
        XCTAssertEqual(overscroll, 0)
    }

    func testOverscrollUsesNegativeAdjustedContentOffset() {
        let overscroll = HeroHeaderLayout.overscroll(contentOffsetY: -132, topInset: 44)
        XCTAssertEqual(overscroll, 88)
    }

    func testOverscrollMetricsExpandHeightAndPinTopEdge() {
        let metrics = HeroHeaderLayout.overscrollMetrics(baseHeight: 520, overscroll: 88)

        XCTAssertEqual(metrics.height, 608)
        XCTAssertEqual(metrics.offsetY, -88)
    }

    func testOverscrollMetricsDoNotMoveAtRest() {
        let metrics = HeroHeaderLayout.overscrollMetrics(baseHeight: 520, overscroll: 0)

        XCTAssertEqual(metrics.height, 520)
        XCTAssertEqual(metrics.offsetY, 0)
    }
}
