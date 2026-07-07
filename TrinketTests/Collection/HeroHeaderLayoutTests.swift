import Testing
@testable import Trinket

@Suite
struct HeroHeaderLayoutTests {
    // MARK: - Header height (3:4 of width, minimum 300)

    @Test func headerHeightMatchesThreeToFourAspect() {
        let width: CGFloat = 390
        let height = HeroHeaderLayout.headerHeight(forWidth: width)
        let aspect = height / width
        #expect(abs((aspect) - (4.0 / 3.0)) < 0.001)
    }

    @Test func headerHeightHasMinimumOf300() {
        let width: CGFloat = 100
        let height = HeroHeaderLayout.headerHeight(forWidth: width)
        #expect(height == 300)
    }

    @Test func headerHeightAtMinimumThreshold() {
        let width: CGFloat = 225
        let height = HeroHeaderLayout.headerHeight(forWidth: width)
        #expect(height == 300)
    }

    @Test func headerHeightAboveMinimumUsesWidth() {
        let width: CGFloat = 300
        let height = HeroHeaderLayout.headerHeight(forWidth: width)
        #expect(abs((height) - (400)) < 0.5)
    }

    @Test func headerHeightForCommonDeviceWidths() {
        let widths: [(CGFloat, CGFloat)] = [
            (320, 427),
            (375, 500),
            (390, 520),
            (414, 552),
            (428, 571)
        ]
        for (width, expected) in widths {
            let height = HeroHeaderLayout.headerHeight(forWidth: width)
            #expect(abs((height) - (expected)) < 1,
                           "Expected height for width \(width)")
        }
    }

    // MARK: - Overscroll stretch contract

    @Test func overscrollIsZeroWhenContentIsNotPulledPastTop() {
        let overscroll = HeroHeaderLayout.overscroll(contentOffsetY: 20, topInset: 0)
        #expect(overscroll == 0)
    }

    @Test func overscrollUsesNegativeAdjustedContentOffset() {
        let overscroll = HeroHeaderLayout.overscroll(contentOffsetY: -132, topInset: 44)
        #expect(overscroll == 88)
    }

    @Test func overscrollMetricsExpandHeightAndPinTopEdge() {
        let metrics = HeroHeaderLayout.overscrollMetrics(baseHeight: 520, overscroll: 88)

        #expect(metrics.height == 608)
        #expect(metrics.offsetY == -88)
    }

    @Test func overscrollMetricsDoNotMoveAtRest() {
        let metrics = HeroHeaderLayout.overscrollMetrics(baseHeight: 520, overscroll: 0)

        #expect(metrics.height == 520)
        #expect(metrics.offsetY == 0)
    }
}
