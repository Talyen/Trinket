import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

/// Single owner for the inventory salvage-detail state machine shared by the
/// Collection shelf and the full Inventory grid: sheet selection, dissolve
/// tombstone re-insert, salvage haptics, and the dissolve-finish animation.
@MainActor
@Observable
final class SalvageItemDetailController {
    var selectedItem: InventoryItem?
    var selectedItemIndex: Int?
    var dissolvingTombstone: SalvageDissolveTombstone?
    var salvageSuccessCount = 0

    func select(_ item: InventoryItem, at index: Int?) {
        selectedItem = item
        selectedItemIndex = index
    }

    func salvageFinished(
        didSucceed: Bool,
        item: InventoryItem,
        resolveIndex: (InventoryItem) -> Int
    ) {
        if didSucceed {
            dissolvingTombstone = SalvageDissolveTombstone(
                item: item,
                index: selectedItemIndex ?? resolveIndex(item)
            )
            salvageSuccessCount += 1
        }
        selectedItem = nil
        selectedItemIndex = nil
    }

    func finishDissolve() {
        withAnimation(TrinketMotion.Reward.stateChange) {
            dissolvingTombstone = nil
        }
    }
}

/// Shared inventory-salvage detail sheet. Sheet lifecycle and the tombstone
/// re-insert live here; index resolution stays with the presenting screen so
/// the Collection shelf (full inventory) and Inventory grid (filtered) each
/// re-insert at the position the player actually saw.
struct SalvageItemDetailSheet: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    let controller: SalvageItemDetailController
    let item: InventoryItem
    let zoomNamespace: Namespace.ID
    let resolveIndex: (InventoryItem) -> Int

    var body: some View {
        NavigationStack {
            ItemDetailView.inventorySalvageDetail(item: item, saveStore: playerSave) { didSucceed in
                controller.salvageFinished(
                    didSucceed: didSucceed,
                    item: item,
                    resolveIndex: resolveIndex
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
