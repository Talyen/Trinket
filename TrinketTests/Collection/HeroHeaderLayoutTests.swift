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

    // MARK: - Overscroll scale (uniform zoom, 1.0 at rest)

    func testScaleIsOneAtRest() {
        let scale = HeroHeaderLayout.overscrollScale(baseHeight: 520, pullDistance: 0)
        XCTAssertEqual(scale, 1.0, accuracy: 0.001)
    }

    func testScaleIsGreaterThanOneDuringPull() {
        let scale = HeroHeaderLayout.overscrollScale(baseHeight: 520, pullDistance: 100)
        XCTAssertGreaterThan(scale, 1.0)
    }

    func testScaleAtCommonPullDistances() {
        let base: CGFloat = 520
        let pulls: [(CGFloat, CGFloat)] = [
            (0, 1.0),
            (50, 1.096),
            (100, 1.192),
            (150, 1.288),
            (200, 1.385)
        ]
        for (pull, expected) in pulls {
            let scale = HeroHeaderLayout.overscrollScale(baseHeight: base, pullDistance: pull)
            XCTAssertEqual(scale, expected, accuracy: 0.005,
                           "Scale for pullDistance \(pull)")
        }
    }

    func testScaleWithDifferentBaseHeights() {
        let scale1 = HeroHeaderLayout.overscrollScale(baseHeight: 300, pullDistance: 50)
        let scale2 = HeroHeaderLayout.overscrollScale(baseHeight: 520, pullDistance: 50)
        XCTAssertNotEqual(scale1, scale2)
        XCTAssertGreaterThan(scale1, scale2)
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
