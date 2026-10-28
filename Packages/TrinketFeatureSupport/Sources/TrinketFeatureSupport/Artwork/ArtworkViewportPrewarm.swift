import Foundation

public enum ArtworkViewportPrewarm {
    public static let defaultPrefetchRows = 3
    public static let collectionEstimatedColumns = 2
    public static let partyPickerEstimatedColumns = 3
    public static let backwardPrefetchRows = 1
    public static let viewportDebounceInterval: Duration = .milliseconds(50)

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
        orderedItems: [Item],
        visibleIDs: Set<Item.ID>,
        thumbnailName: (Item) -> String?,
        prefetchRows: Int,
        estimatedColumns: Int,
    ) -> [String] where Item.ID: Hashable {
        guard !orderedItems.isEmpty else { return [] }
        let visibleIndices = visibleIDs.isEmpty ? [] : orderedItems.indices.filter {
            visibleIDs.contains(orderedItems[$0].id)
        }
        guard !visibleIndices.isEmpty else {
            let initialCount = min(orderedItems.count, prefetchRows * estimatedColumns * 2)
            return dedupedNames(for: orderedItems.prefix(initialCount), thumbnailName: thumbnailName)
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
