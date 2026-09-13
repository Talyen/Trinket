import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct SalvageDetailState {
    var requestedItem: InventoryItem?
    var selectedItem: InventoryItem?
    private var selectedInventoryIndex: Int?
    var transmutationEvent: SalvageTransmutationEvent?
    var salvageSuccessCount = 0
    var salvageErrorCount = 0

    mutating func select(_ item: InventoryItem, inventory: [InventoryItem]) {
        withAnimation(TrinketMotion.Reward.stateChange) {
            transmutationEvent = nil
        }
        selectedInventoryIndex = inventory.firstIndex { $0.id == item.id }
        requestedItem = item
    }

    func presentationItems(in inventory: [InventoryItem]) -> [InventoryItem] {
        guard let event = transmutationEvent, let index = event.inventoryIndex,
              !inventory.contains(where: { $0.id == event.item.id }) else { return inventory }
        var items = inventory
        items.insert(event.item, at: min(index, items.count))
        return items
    }

    mutating func salvageFinished(
        result: ItemSalvageActionResult,
        item: InventoryItem,
    ) {
        if case let .success(yields) = result {
            transmutationEvent = SalvageTransmutationEvent(
                item: item,
                yields: yields,
                inventoryIndex: selectedInventoryIndex,
            )
            salvageSuccessCount += 1
        } else if case .persistenceFailure = result {
            salvageErrorCount &+= 1
            return
        }
    }

    mutating func detailDismissed() {
        if selectedItem == nil, requestedItem == nil {
            selectedInventoryIndex = nil
        }
        transmutationEvent?.hasReturned = true
    }

    mutating func finishTransmutation(id: UUID) {
        guard transmutationEvent?.id == id else { return }
        withAnimation(TrinketMotion.Reward.stateChange) {
            transmutationEvent = nil
        }
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
