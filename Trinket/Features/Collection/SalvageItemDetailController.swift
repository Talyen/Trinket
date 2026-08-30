import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct SalvageDetailState {
    var selectedItem: InventoryItem?
    var transmutationEvent: SalvageTransmutationEvent?
    var salvageSuccessCount = 0

    mutating func select(_ item: InventoryItem) {
        selectedItem = item
    }

    mutating func salvageFinished(
        result: ItemSalvageActionResult,
        item: InventoryItem,
    ) {
        if case let .success(yields) = result {
            transmutationEvent = SalvageTransmutationEvent(
                item: item,
                yields: yields,
            )
            salvageSuccessCount += 1
        }
        var dismiss = Transaction()
        dismiss.disablesAnimations = true
        withTransaction(dismiss) {
            selectedItem = nil
        }
    }

    mutating func finishTransmutation(id: UUID) {
        guard transmutationEvent?.id == id else { return }
        transmutationEvent = nil
    }
}

struct SalvageItemDetailSheet: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    let item: InventoryItem
    let onFinished: (ItemSalvageActionResult) -> Void

    var body: some View {
        NavigationStack {
            ItemDetailView.inventorySalvageDetail(item: item, saveStore: playerSave) { result in
                onFinished(result)
            }
        }
        .trinketDetailSheet()
        .appFramePacingSignpost(
            AppFramePacingSignposts.Name.sheetPresent,
            isActive: true,
        )
        .onAppear {
            AppFramePacingSignposts.event(
                AppFramePacingSignposts.Name.sheetPresent,
                detail: "collectionItem=\(item.id)",
            )
        }
    }
}
