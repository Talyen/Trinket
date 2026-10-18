import Foundation

public enum ArtworkViewportPrewarm {
    public static let defaultPrefetchRows = 3
    public static let collectionEstimatedColumns = 2
    public static let partyPickerEstimatedColumns = 3
    public static let backwardPrefetchRows = 1
    public static let viewportDebounceInterval: Duration = .milliseconds(50)

    public struct Window<Item: Identifiable> where Item.ID: Hashable {
        public let orderedItems: [Item]

        public init(orderedItems: [Item]) {
            self.orderedItems = orderedItems
        }

        fileprivate func visibleIndices(matching ids: Set<Item.ID>) -> [Int] {
            guard !ids.isEmpty else { return [] }
            var indices: [Int] = []
            indices.reserveCapacity(min(ids.count, orderedItems.count))
            for (offset, item) in orderedItems.enumerated() where ids.contains(item.id) {
                indices.append(offset)
            }
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
        await prewarm(
            orderedItems: window.orderedItems,
            visibleIDs: visibleIDs,
            currentVisibleIDs: currentVisibleIDs,
            thumbnailName: thumbnailName,
            prefetchRows: prefetchRows,
            estimatedColumns: estimatedColumns,
        )
    }

    /// Debounce, re-read the visible IDs, then prepare.
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
        guard visibleIndices.first != nil else {
            return initialWindowNames(
                orderedItems: orderedItems,
                thumbnailName: thumbnailName,
                prefetchRows: prefetchRows,
                estimatedColumns: estimatedColumns,
            )
        }
        let forwardCount = prefetchRows * estimatedColumns
        let backwardCount = backwardPrefetchRows * estimatedColumns
        // Visible indices ascend, so merge overlapping expanded intervals in one pass.
        var seen = Set<String>()
        var result: [String] = []
        var windowEnd = -1
        for visible in visibleIndices {
            let start = max(0, visible - backwardCount)
            let end = min(orderedItems.count - 1, visible + forwardCount)
            let clampedStart = max(start, windowEnd + 1)
            guard clampedStart <= end else { continue }
            windowEnd = end
            for item in orderedItems[clampedStart ... end] {
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
