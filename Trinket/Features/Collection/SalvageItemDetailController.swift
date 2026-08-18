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

    func select(_ item: InventoryItem) {
        selectedItem = item
    }

    func salvageFinished(
        result: ItemSalvageActionResult,
        item: InventoryItem
    ) {
        if case let .success(yields) = result {
            transmutationEvent = SalvageTransmutationEvent(
                item: item,
                yields: yields
            )
            salvageSuccessCount += 1
        }
        var dismiss = Transaction()
        dismiss.disablesAnimations = true
        withTransaction(dismiss) {
            selectedItem = nil
        }
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

    var body: some View {
        NavigationStack {
            ItemDetailView.inventorySalvageDetail(item: item, saveStore: playerSave) { result in
                controller.salvageFinished(
                    result: result,
                    item: item
                )
            }
        }
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
