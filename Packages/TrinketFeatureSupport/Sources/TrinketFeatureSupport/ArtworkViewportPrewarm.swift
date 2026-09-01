import SwiftUI

@MainActor
public enum ArtworkViewportPrewarm {
    public static let defaultPrefetchRows = 3
    public static let collectionEstimatedColumns = 2
    public static let partyPickerEstimatedColumns = 3
    private static let backwardPrefetchRows = 1
    public static let viewportDebounceInterval: Duration = .milliseconds(50)

    public static func prewarm<Item: Identifiable>(
        orderedItems: [Item],
        visibleIDs: Set<Item.ID>,
        currentVisibleIDs: (() -> Set<Item.ID>)? = nil,
        thumbnailName: (Item) -> String?,
        prefetchRows: Int = defaultPrefetchRows,
        estimatedColumns: Int = collectionEstimatedColumns,
    ) async where Item.ID: Hashable {
        try? await Task.sleep(for: viewportDebounceInterval)
        guard !Task.isCancelled else { return }
        let latestIDs: Set<Item.ID> = currentVisibleIDs?() ?? visibleIDs
        let names = windowNames(
            orderedItems: orderedItems,
            visibleIDs: latestIDs,
            thumbnailName: thumbnailName,
            prefetchRows: prefetchRows,
            estimatedColumns: estimatedColumns,
        )
        guard !names.isEmpty else { return }
        await PreparedArtworkCache.shared.prepare(names: names)
    }

    public static func windowNames<Item: Identifiable>(
        orderedItems: [Item],
        visibleIDs: Set<Item.ID>,
        thumbnailName: (Item) -> String?,
        prefetchRows: Int,
        estimatedColumns: Int,
    ) -> [String] where Item.ID: Hashable {
        windowNames(
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
        guard let minVisible = visibleIndices.min(), let maxVisible = visibleIndices.max() else {
            return initialWindowNames(
                orderedItems: orderedItems,
                thumbnailName: thumbnailName,
                prefetchRows: prefetchRows,
                estimatedColumns: estimatedColumns,
            )
        }
        let forwardCount = prefetchRows * estimatedColumns
        let backwardCount = backwardPrefetchRows * estimatedColumns
        let windowStart = max(0, minVisible - backwardCount)
        let windowEnd = min(orderedItems.count - 1, maxVisible + forwardCount)
        return dedupedNames(for: orderedItems[windowStart ... windowEnd], thumbnailName: thumbnailName)
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
