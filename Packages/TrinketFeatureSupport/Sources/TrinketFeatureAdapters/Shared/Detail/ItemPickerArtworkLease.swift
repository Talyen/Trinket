import TrinketContent
import TrinketFeatureSupport

@MainActor
final class ItemPickerArtworkLease {
    private let lease: PreparedArtworkLease

    init(items: [InventoryItem]) async {
        let requested = ArtworkViewportPrewarm.windowNames(
            orderedItems: items,
            visibleIDs: Set<String>(),
            thumbnailName: { $0.artReference?.thumbnailImageName ?? $0.artReference?.imageName },
            prefetchRows: ArtworkViewportPrewarm.defaultPrefetchRows,
            estimatedColumns: ArtworkViewportPrewarm.partyPickerEstimatedColumns,
        )
        lease = await PreparedArtworkLease(names: requested)
    }
}
