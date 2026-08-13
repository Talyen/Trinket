import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

/// Single owner for the inventory salvage-detail state machine shared by the
/// Collection shelf and the full Inventory grid.
@MainActor
@Observable
final class SalvageItemDetailController {
    var selectedItem: InventoryItem?
    var transmutationEvent: SalvageTransmutationEvent?
    var salvageSuccessCount = 0
    private var selectedSourceFrame: CGRect?
    private var selectedShowsName = true

    func select(
        _ item: InventoryItem,
        sourceFrame: CGRect? = nil,
        showsName: Bool = true
    ) {
        selectedItem = item
        selectedSourceFrame = sourceFrame
        selectedShowsName = showsName
    }

    func salvageFinished(
        result: ItemSalvageActionResult,
        item: InventoryItem
    ) {
        if case let .success(yields) = result {
            transmutationEvent = SalvageTransmutationEvent(
                item: item,
                yields: yields,
                sourceFrame: selectedSourceFrame,
                showsName: selectedShowsName
            )
            salvageSuccessCount += 1
        }
        selectedItem = nil
        selectedSourceFrame = nil
        selectedShowsName = true
    }

    func finishTransmutation(id: UUID) {
        guard transmutationEvent?.id == id else { return }
        transmutationEvent = nil
    }
}

/// Shared inventory-salvage detail sheet. The committed result is handed back
/// to presentation state while inventory data remains the grid's sole source.
struct SalvageItemDetailSheet: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    let controller: SalvageItemDetailController
    let item: InventoryItem
    let zoomNamespace: Namespace.ID

    var body: some View {
        NavigationStack {
            ItemDetailView.inventorySalvageDetail(item: item, saveStore: playerSave) { result in
                controller.salvageFinished(
                    result: result,
                    item: item
                )
            }
        }
        .navigationTransition(.zoom(sourceID: item.id, in: zoomNamespace))
        .trinketDetailSheet()
        .appFramePacingSignpost(
            AppFramePacingSignposts.Name.sheetPresent,
            isActive: true
        )
        .onAppear {
            AppFramePacingSignposts.event(
                AppFramePacingSignposts.Name.sheetPresent,
                detail: "collectionItem=\(item.id)"
            )
        }
    }
}
