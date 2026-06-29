import SwiftUI

@Observable
final class PlayerInventoryStore {
    var current: PlayerInventoryState = .initial

    var items: [InventoryItem] {
        current.items
    }

    func items(for slot: ItemSlot) -> [InventoryItem] {
        current.items(for: slot)
    }

    func item(matching id: String?) -> InventoryItem? {
        current.item(matching: id)
    }
}
