import Foundation

/// Thin domain facade over `PlayerSaveStore` for journey progress.
/// Does not own a container — all writes route through the hub.
@MainActor
public struct PlayerJourneyStore {
    private let save: PlayerSaveStore

    public init(save: PlayerSaveStore) {
        self.save = save
    }

    public var state: JourneyProgressState {
        get { save.journey }
        nonmutating set { save.journey = newValue }
    }
}
