import SwiftUI

@MainActor
@Observable
final class PlayerInventoryStore {
    private let saveStore: PlayerSaveStore

    var current: PlayerInventoryState {
        get { saveStore.inventory }
        set { saveStore.inventory = newValue }
    }

    init(saveStore: PlayerSaveStore) {
        self.saveStore = saveStore
    }

    var items: [InventoryItem] {
        current.items
    }

    func items(for slot: ItemSlot) -> [InventoryItem] {
        current.items(for: slot)
    }

    func item(matching id: String?) -> InventoryItem? {
        current.item(matching: id)
    }

    func addRewardItem(from template: InventoryItem, for stage: Stage) {
        var updated = current
        updated.addRewardItem(from: template, for: stage)
        current = updated
    }
}
