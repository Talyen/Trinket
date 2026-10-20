import Observation
import SwiftUI

/// Tracks the IDs currently visible in a lazy grid so artwork prewarm follows the viewport.
@MainActor
@Observable
public final class ArtworkViewportTracker<ID: Hashable> {
    public var visibleIDs: Set<ID> = []

    public init() {}
}

/// One ordered grid item and the artwork name it should prewarm.
public struct ArtworkViewportEntry<ID: Hashable>: Identifiable, Equatable {
    public let id: ID
    public let name: String?

    public init(id: ID, name: String?) {
        self.id = id
        self.name = name
    }
}

/// Debounced viewport observer shared by lazy grids that prewarm prepared artwork.
public struct ArtworkViewportPrewarmObserver<ID: Hashable>: View {
    private struct Key: Equatable {
        let visibleIDs: Set<ID>
        let generation: Int
        let prefetchRows: Int
        let estimatedColumns: Int
    }

    let entries: [ArtworkViewportEntry<ID>]
    @State private var window = ArtworkViewportPrewarm.Window<ArtworkViewportEntry<ID>>(orderedItems: [])
    @State private var generation = 0
    let viewport: ArtworkViewportTracker<ID>
    let prefetchRows: Int
    let estimatedColumns: Int

    public init(
        entries: [ArtworkViewportEntry<ID>],
        viewport: ArtworkViewportTracker<ID>,
        prefetchRows: Int = ArtworkViewportPrewarm.defaultPrefetchRows,
        estimatedColumns: Int = ArtworkViewportPrewarm.collectionEstimatedColumns,
    ) {
        self.entries = entries
        self.viewport = viewport
        self.prefetchRows = prefetchRows
        self.estimatedColumns = estimatedColumns
    }

    public var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: entries, initial: true) { _, entries in
                window = ArtworkViewportPrewarm.Window(orderedItems: entries)
                viewport.visibleIDs.formIntersection(entries.map(\.id))
                generation &+= 1
            }
            .task(id: Key(
                visibleIDs: viewport.visibleIDs,
                generation: generation,
                prefetchRows: prefetchRows,
                estimatedColumns: estimatedColumns,
            )) {
                await ArtworkViewportPrewarm.prewarm(
                    window: window,
                    visibleIDs: viewport.visibleIDs,
                    currentVisibleIDs: { viewport.visibleIDs },
                    thumbnailName: { $0.name },
                    prefetchRows: prefetchRows,
                    estimatedColumns: estimatedColumns,
                )
            }
    }
}
