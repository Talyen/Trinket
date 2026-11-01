import Testing
@testable import TrinketFeatureSupport

struct HeroHeaderLayoutTests {
    @Test func `title stays pinned through small movements at hero edge`() {
        #expect(!HeroHeaderLayout.titleIsPinned(opacity: 0.5, wasPinned: false))
        #expect(HeroHeaderLayout.titleIsPinned(opacity: 0.75, wasPinned: false))
        #expect(HeroHeaderLayout.titleIsPinned(opacity: 0.5, wasPinned: true))
        #expect(!HeroHeaderLayout.titleIsPinned(opacity: 0.25, wasPinned: true))
    }

    @Test func `bottom bounce does not reveal title on short sheet`() {
        let atBottom = HeroHeaderLayout.titleOpacity(
            offsetY: 100, contentHeight: 900, viewportHeight: 800,
            topInset: 0, bottomInset: 0, headerHeight: 110,
        )
        let bouncing = HeroHeaderLayout.titleOpacity(
            offsetY: 160, contentHeight: 900, viewportHeight: 800,
            topInset: 0, bottomInset: 0, headerHeight: 110,
        )
        #expect(atBottom == 0)
        #expect(bouncing == atBottom)
    }

    @Test func `title still fades within reachable scroll range`() {
        let opacity = HeroHeaderLayout.titleOpacity(
            offsetY: 96, contentHeight: 1200, viewportHeight: 800,
            topInset: 20, bottomInset: 10, headerHeight: 110,
        )
        #expect(opacity == 0.8125)
    }
}
