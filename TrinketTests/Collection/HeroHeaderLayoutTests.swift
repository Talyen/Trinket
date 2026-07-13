import CoreGraphics
import Testing
@testable import Trinket

struct HeroHeaderLayoutTests {
    // MARK: - Header height (3:4 of width, minimum 300)

    @Test func headerHeightMatchesThreeToFourAspect() {
        let width: CGFloat = 390
        let height = HeroHeaderLayout.headerHeight(forWidth: width)
        let aspect = height / width
        #expect(abs(aspect - (4.0 / 3.0)) < 0.001)
    }

    @Test func headerHeightHasMinimumOf300() {
        #expect(HeroHeaderLayout.headerHeight(forWidth: 100) == 300)
        #expect(HeroHeaderLayout.headerHeight(forWidth: 225) == 300)
    }

    @Test func headerHeightAboveMinimumUsesWidth() {
        let width: CGFloat = 300
        let height = HeroHeaderLayout.headerHeight(forWidth: width)
        #expect(abs(height - 400) < 0.5)
    }

    @Test func cinematicHeightIsDenseAndClamped() {
        #expect(HeroHeaderLayout.HeightPolicy.cinematicLandscape.height(forWidth: 320) == 288)
        #expect(abs(HeroHeaderLayout.HeightPolicy.cinematicLandscape.height(forWidth: 390) - 304.2) < 0.1)
        #expect(HeroHeaderLayout.HeightPolicy.cinematicLandscape.height(forWidth: 500) == 344)
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
