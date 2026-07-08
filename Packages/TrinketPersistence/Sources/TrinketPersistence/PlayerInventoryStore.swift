import Foundation

/// Thin domain facade over `PlayerSaveStore` for inventory.
/// Does not own a container — all writes route through the hub.
@MainActor
public struct PlayerInventoryStore {
    private let save: PlayerSaveStore

    public init(save: PlayerSaveStore) {
        self.save = save
    }

    public var state: PlayerInventoryState {
        get { save.inventory }
        nonmutating set { save.inventory = newValue }
    }
}
