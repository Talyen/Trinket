import TrinketContent
import TrinketFeatureSupport

@MainActor
final class ItemPickerArtworkLease {
    private let names: [String]

    init(items: [InventoryItem]) async {
        names = ArtworkViewportPrewarm.windowNames(
            orderedItems: items,
            visibleIDs: Set<String>(),
            thumbnailName: { $0.artReference?.thumbnailImageName ?? $0.artReference?.imageName },
            prefetchRows: ArtworkViewportPrewarm.defaultPrefetchRows,
            estimatedColumns: ArtworkViewportPrewarm.partyPickerEstimatedColumns,
        )
        await PreparedArtworkCache.shared.prepareAndPin(names: names)
    }

    isolated deinit {
        PreparedArtworkCache.shared.releasePins(names: names)
    }
}
