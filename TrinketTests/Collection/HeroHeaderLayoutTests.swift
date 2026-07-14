import CoreGraphics
import Testing
@testable import Trinket

struct HeroHeaderLayoutTests {
    // MARK: - Header height (3:4 of width, minimum 300)

    @Test func headerHeightUsesThreeToFourAspectWithMinimumFloor() {
        #expect(HeroHeaderLayout.headerHeight(forWidth: 100) == 300)
        #expect(HeroHeaderLayout.headerHeight(forWidth: 225) == 300)

        let aboveFloorWidth: CGFloat = 300
        let aboveFloorHeight = HeroHeaderLayout.headerHeight(forWidth: aboveFloorWidth)
        #expect(abs(aboveFloorHeight - 400) < 0.5)

        let aspectWidth: CGFloat = 390
        let aspectHeight = HeroHeaderLayout.headerHeight(forWidth: aspectWidth)
        #expect(abs(aspectHeight / aspectWidth - (4.0 / 3.0)) < 0.001)
    }

    @Test func cinematicHeightIsDenserThanStandardAndClamped() {
        let narrow = HeroHeaderLayout.HeightPolicy.cinematicLandscape.height(forWidth: 320)
        let mid = HeroHeaderLayout.HeightPolicy.cinematicLandscape.height(forWidth: 390)
        let wide = HeroHeaderLayout.HeightPolicy.cinematicLandscape.height(forWidth: 500)
        let standardMid = HeroHeaderLayout.headerHeight(forWidth: 390)

        #expect(mid < standardMid)
        #expect(narrow <= mid)
        #expect(mid <= wide)
        #expect(narrow == HeroHeaderLayout.HeightPolicy.cinematicLandscape.height(forWidth: 300))
        #expect(wide == HeroHeaderLayout.HeightPolicy.cinematicLandscape.height(forWidth: 600))
    }

    // MARK: - Overscroll stretch contract

    @Test func overscrollContractCoversOffsetAndMetrics() {
        #expect(HeroHeaderLayout.overscroll(contentOffsetY: 20, topInset: 0) == 0)
        #expect(HeroHeaderLayout.overscroll(contentOffsetY: -132, topInset: 44) == 88)

        let stretched = HeroHeaderLayout.overscrollMetrics(baseHeight: 520, overscroll: 88)
        #expect(stretched.height == 608)
        #expect(stretched.offsetY == -88)

        let atRest = HeroHeaderLayout.overscrollMetrics(baseHeight: 520, overscroll: 0)
        #expect(atRest.height == 520)
        #expect(atRest.offsetY == 0)
    }
}
