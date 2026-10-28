import Testing
@testable import TrinketFeatureSupport

private struct ViewportItem: Identifiable, Equatable {
    let id: String
    let thumbnail: String
}

@MainActor
struct ArtworkViewportPrewarmTests {
    @Test func `filtered and reordered artwork follows the current catalog order`() {
        let items = (0 ..< 30).reversed().filter { $0 != 10 }.map {
            ViewportItem(id: "\($0)", thumbnail: "new-thumb\($0 / 2)")
        }
        let names = ArtworkViewportPrewarm.windowNames(
            orderedItems: items, visibleIDs: ["0", "10", "29"], thumbnailName: { $0.thumbnail },
            prefetchRows: 1, estimatedColumns: 2,
        )
        #expect(names == ["new-thumb14", "new-thumb13", "new-thumb1", "new-thumb0"])
    }

    @Test(arguments: [Set<String>(), Set(["missing"])])
    func `no matching visible IDs prefetches initial window`(visibleIDs: Set<String>) {
        let items = (0 ..< 20).map { ViewportItem(id: "\($0)", thumbnail: "thumb\($0)") }
        let names = ArtworkViewportPrewarm.windowNames(
            orderedItems: items,
            visibleIDs: visibleIDs,
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

    @Test func `dispersed visible items prewarm per cluster`() {
        let items = (0 ..< 20).map { ViewportItem(id: "\($0)", thumbnail: "thumb\($0)") }
        let names = ArtworkViewportPrewarm.windowNames(
            orderedItems: items,
            visibleIDs: ["0", "10"],
            thumbnailName: { $0.thumbnail },
            prefetchRows: 1,
            estimatedColumns: 1,
        )
        #expect(names == ["thumb0", "thumb1", "thumb9", "thumb10", "thumb11"])
    }
}
