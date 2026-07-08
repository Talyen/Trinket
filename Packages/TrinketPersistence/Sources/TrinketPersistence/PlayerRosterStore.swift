import Foundation

/// Thin domain facade over `PlayerSaveStore` for roster / gold / loadouts.
/// Does not own a container — all writes route through the hub.
@MainActor
public struct PlayerRosterStore {
    private let save: PlayerSaveStore

    public init(save: PlayerSaveStore) {
        self.save = save
    }

    public var state: PlayerRosterState {
        get { save.roster }
        nonmutating set { save.roster = newValue }
    }
}
