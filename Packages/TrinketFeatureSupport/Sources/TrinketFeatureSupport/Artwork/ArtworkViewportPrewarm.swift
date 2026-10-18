import Foundation

public enum ArtworkViewportPrewarm {
    public static let defaultPrefetchRows = 3
    public static let collectionEstimatedColumns = 2
    public static let partyPickerEstimatedColumns = 3
    public static let backwardPrefetchRows = 1
    public static let viewportDebounceInterval: Duration = .milliseconds(50)

    public struct Window<Item: Identifiable> where Item.ID: Hashable {
        public let orderedItems: [Item]
        private let firstIndicesByID: [Item.ID: Int]
        private let nextIndices: [Int]

        public init(orderedItems: [Item]) {
            self.orderedItems = orderedItems
            var firstIndices: [Item.ID: Int] = [:]
            firstIndices.reserveCapacity(orderedItems.count)
            // A contiguous chain preserves repeated IDs without allocating an array per item.
            var nextIndices = [Int](repeating: -1, count: orderedItems.count)
            for index in orderedItems.indices.reversed() {
                nextIndices[index] = firstIndices.updateValue(index, forKey: orderedItems[index].id) ?? -1
            }
            firstIndicesByID = firstIndices
            self.nextIndices = nextIndices
        }

        fileprivate func visibleIndices(matching ids: Set<Item.ID>) -> [Int] {
            var indices: [Int] = []
            indices.reserveCapacity(ids.count)
            for id in ids {
                var index = firstIndicesByID[id] ?? -1
                while index != -1 {
                    indices.append(index)
                    index = nextIndices[index]
                }
            }
            indices.sort()
            return indices
        }
    }

    @MainActor
    public static func prewarm<Item: Identifiable>(
        orderedItems: [Item],
        visibleIDs: Set<Item.ID>,
        currentVisibleIDs: (() -> Set<Item.ID>)? = nil,
        thumbnailName: (Item) -> String?,
        prefetchRows: Int = defaultPrefetchRows,
        estimatedColumns: Int = collectionEstimatedColumns,
    ) async where Item.ID: Hashable {
        await prewarm(hasVisibleIDs: !visibleIDs.isEmpty) {
            let latestIDs: Set<Item.ID> = currentVisibleIDs?() ?? visibleIDs
            return windowNames(
                orderedItems: orderedItems,
                visibleIDs: latestIDs,
                thumbnailName: thumbnailName,
                prefetchRows: prefetchRows,
                estimatedColumns: estimatedColumns,
            )
        }
    }

    @MainActor
    public static func prewarm<Item: Identifiable>(
        window: Window<Item>,
        visibleIDs: Set<Item.ID>,
        currentVisibleIDs: (() -> Set<Item.ID>)? = nil,
        thumbnailName: (Item) -> String?,
        prefetchRows: Int = defaultPrefetchRows,
        estimatedColumns: Int = collectionEstimatedColumns,
    ) async where Item.ID: Hashable {
        await prewarm(hasVisibleIDs: !visibleIDs.isEmpty) {
            let latestIDs: Set<Item.ID> = currentVisibleIDs?() ?? visibleIDs
            return windowNames(
                window: window, visibleIDs: latestIDs, thumbnailName: thumbnailName,
                prefetchRows: prefetchRows, estimatedColumns: estimatedColumns,
            )
        }
    }

    /// Debounce, re-read the visible IDs, then prepare. Both overloads share
    /// this tail; only `windowNames` resolution differs.
    @MainActor
    private static func prewarm(hasVisibleIDs: Bool, names: () -> [String]) async {
        if hasVisibleIDs {
            try? await Task.sleep(for: viewportDebounceInterval)
        }
        guard !Task.isCancelled else { return }
        let resolved = names()
        guard !resolved.isEmpty else { return }
        await PreparedArtworkCache.shared.prepare(names: resolved)
    }

    public static func windowNames<Item: Identifiable>(
        window: Window<Item>,
        visibleIDs: Set<Item.ID>,
        thumbnailName: (Item) -> String?,
        prefetchRows: Int,
        estimatedColumns: Int,
    ) -> [String] where Item.ID: Hashable {
        windowNames(
            orderedItems: window.orderedItems,
            visibleIndices: window.visibleIndices(matching: visibleIDs),
            thumbnailName: thumbnailName,
            prefetchRows: prefetchRows,
            estimatedColumns: estimatedColumns,
        )
    }

    public static func windowNames<Item: Identifiable>(
        orderedItems: [Item],
        visibleIDs: Set<Item.ID>,
        thumbnailName: (Item) -> String?,
        prefetchRows: Int,
        estimatedColumns: Int,
    ) -> [String] where Item.ID: Hashable {
        // Initial presentation only needs the prefix, regardless of catalog size.
        guard !orderedItems.isEmpty else { return [] }
        guard !visibleIDs.isEmpty else {
            return initialWindowNames(
                orderedItems: orderedItems,
                thumbnailName: thumbnailName,
                prefetchRows: prefetchRows,
                estimatedColumns: estimatedColumns,
            )
        }
        return windowNames(
            orderedItems: orderedItems,
            visibleIndices: visibleIndices(for: orderedItems, matching: { visibleIDs.contains($0.id) }),
            thumbnailName: thumbnailName,
            prefetchRows: prefetchRows,
            estimatedColumns: estimatedColumns,
        )
    }

    private static func windowNames<Item: Identifiable>(
        orderedItems: [Item],
        visibleIndices: [Int],
        thumbnailName: (Item) -> String?,
        prefetchRows: Int,
        estimatedColumns: Int,
    ) -> [String] {
        guard !orderedItems.isEmpty else { return [] }
        guard let minVisible = visibleIndices.first, let maxVisible = visibleIndices.last else {
            return initialWindowNames(
                orderedItems: orderedItems,
                thumbnailName: thumbnailName,
                prefetchRows: prefetchRows,
                estimatedColumns: estimatedColumns,
            )
        }
        let forwardCount = prefetchRows * estimatedColumns
        let backwardCount = backwardPrefetchRows * estimatedColumns
        let span = maxVisible - minVisible + 1
        if span > visibleIndices.count + forwardCount + backwardCount {
            return perClusterNames(
                orderedItems: orderedItems,
                visibleIndices: visibleIndices,
                thumbnailName: thumbnailName,
                prefetchRows: prefetchRows,
                estimatedColumns: estimatedColumns,
            )
        }
        let windowStart = max(0, minVisible - backwardCount)
        let windowEnd = min(orderedItems.count - 1, maxVisible + forwardCount)
        return dedupedNames(for: orderedItems[windowStart ... windowEnd], thumbnailName: thumbnailName)
    }

    private static func perClusterNames<Item: Identifiable>(
        orderedItems: [Item],
        visibleIndices: [Int],
        thumbnailName: (Item) -> String?,
        prefetchRows: Int,
        estimatedColumns: Int,
    ) -> [String] {
        let forwardCount = prefetchRows * estimatedColumns
        let backwardCount = backwardPrefetchRows * estimatedColumns
        var seen = Set<String>()
        var result: [String] = []
        var nextUnvisited = 0
        for visible in visibleIndices {
            // Visible indices ascend, so overlapping windows have already resolved their artwork.
            let start = max(max(0, visible - backwardCount), nextUnvisited)
            let end = min(orderedItems.count - 1, visible + forwardCount)
            guard start <= end else { continue }
            nextUnvisited = end + 1
            for item in orderedItems[start ... end] {
                guard let name = thumbnailName(item), seen.insert(name).inserted else { continue }
                result.append(name)
            }
        }
        return result
    }

    private static func initialWindowNames<Item: Identifiable>(
        orderedItems: [Item],
        thumbnailName: (Item) -> String?,
        prefetchRows: Int,
        estimatedColumns: Int,
    ) -> [String] {
        let initialCount = min(orderedItems.count, prefetchRows * estimatedColumns * 2)
        return dedupedNames(for: orderedItems.prefix(initialCount), thumbnailName: thumbnailName)
    }

    private static func visibleIndices<Item: Identifiable>(
        for orderedItems: [Item],
        matching predicate: (Item) -> Bool,
    ) -> [Int] {
        orderedItems.enumerated().compactMap { predicate($0.element) ? $0.offset : nil }
    }

    private static func dedupedNames<Item>(
        for window: some Sequence<Item>,
        thumbnailName: (Item) -> String?,
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in window {
            guard let name = thumbnailName(item), seen.insert(name).inserted else { continue }
            result.append(name)
        }
        return result
    }
}
