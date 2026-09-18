import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct SalvageDetailState {
    var requestedItem: InventoryItem?
    var selectedItem: InventoryItem?
    private var selectedInventoryIndex: Int?
    var transmutationEvent: SalvageTransmutationEvent?
    var salvageSuccessCount = 0

    mutating func select(_ item: InventoryItem, inventory: [InventoryItem]) {
        withAnimation(TrinketMotion.Reward.collectionStateChange) {
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
            selectedItem = nil
        } else if case .itemNotFound = result {
            selectedItem = nil
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
        withAnimation(TrinketMotion.Reward.collectionStateChange) {
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
        .disabled(playerSave.isRetryingSaveAction)
        .interactiveDismissDisabled(playerSave.isRetryingSaveAction)
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

extension ItemDetailView {
    @MainActor
    static func inventorySalvageDetail(
        item: InventoryItem,
        saveStore: PlayerSaveStore,
        onFinished: @escaping (ItemSalvageActionResult) -> Void,
    ) -> Self {
        let isOwned = saveStore.inventory.items.contains { $0.id == item.id }
        guard isOwned else {
            return Self(item: item)
        }
        guard ItemSalvage.isEligible(item) else {
            return Self(item: item)
        }
        let yields = ItemSalvage.yields(for: item)
        return Self(
            item: item,
            salvageYields: yields,
            equippedByName: saveStore.roster.equippedCombatantName(for: item.id),
            onSalvage: { () -> ItemSalvageActionResult in
                let result = withAnimation(TrinketMotion.Reward.collectionStateChange) {
                    saveStore.salvageItem(id: item.id)
                }
                switch result {
                case let .success(yields):
                    return .success(yields: yields)
                case .itemNotFound:
                    return .itemNotFound
                case .ineligible:
                    return .itemNotFound
                case nil:
                    saveStore.retrySaveAction(key: "salvage-\(item.id)") { [weak saveStore] in
                        guard let saveStore, let result = saveStore.salvageItem(id: item.id) else { return }
                        switch result {
                        case let .success(yields): onFinished(.success(yields: yields))
                        case .itemNotFound, .ineligible: onFinished(.itemNotFound)
                        }
                    }
                    return .persistenceFailure
                }
            },
            onSalvageFinished: onFinished,
        )
    }
}
