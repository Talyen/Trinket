import Testing
@testable import TrinketFeatureSupport

private struct ViewportItem: Identifiable, Equatable {
    let id: String
    let thumbnail: String
}

@MainActor
struct ArtworkViewportPrewarmTests {
    @Test func `empty visible I ds prefetches initial window`() {
        let items = (0 ..< 20).map { ViewportItem(id: "\($0)", thumbnail: "thumb\($0)") }
        let names = ArtworkViewportPrewarm.windowNames(
            orderedItems: items,
            visibleIDs: [],
            thumbnailName: { $0.thumbnail },
            prefetchRows: 3,
            estimatedColumns: 3,
        )
        #expect(names == (0 ..< 18).map { "thumb\($0)" })
    }

    @Test func `visible window includes visible plus three rows ahead`() {
        let items = (0 ..< 20).map { ViewportItem(id: "\($0)", thumbnail: "thumb\($0)") }
        let names = ArtworkViewportPrewarm.windowNames(
            orderedItems: items,
            visibleIDs: ["3", "4", "5"],
            thumbnailName: { $0.thumbnail },
            prefetchRows: 3,
            estimatedColumns: 3,
        )
        #expect(names == (0 ... 14).map { "thumb\($0)" })
    }

    @Test func `window clamps at end of collection`() {
        let items = (0 ..< 10).map { ViewportItem(id: "\($0)", thumbnail: "thumb\($0)") }
        let names = ArtworkViewportPrewarm.windowNames(
            orderedItems: items,
            visibleIDs: ["8", "9"],
            thumbnailName: { $0.thumbnail },
            prefetchRows: 3,
            estimatedColumns: 3,
        )
        #expect(names == (5 ... 9).map { "thumb\($0)" })
    }

    @Test func `deduplicates thumbnail names`() {
        let items = [
            ViewportItem(id: "a", thumbnail: "same"),
            ViewportItem(id: "b", thumbnail: "same"),
            ViewportItem(id: "c", thumbnail: "other"),
        ]
        let names = ArtworkViewportPrewarm.windowNames(
            orderedItems: items,
            visibleIDs: ["a"],
            thumbnailName: { $0.thumbnail },
            prefetchRows: 3,
            estimatedColumns: 3,
        )
        #expect(names == ["same", "other"])
    }

    @Test func `string ID overload matches window logic`() {
        let items = (0 ..< 20).map { ViewportItem(id: "\($0)", thumbnail: "thumb\($0)") }
        let names = ArtworkViewportPrewarm.windowNamesByStringID(
            orderedItems: items,
            visibleIDStrings: ["3", "4"],
            thumbnailName: { $0.thumbnail },
            prefetchRows: 3,
            estimatedColumns: 3,
        )
        #expect(names == (0 ... 13).map { "thumb\($0)" })
    }
}
