import Foundation
import TrinketContent

/// Thin domain facade over `PlayerSaveStore` for homestead.
/// Owns cross-slice player actions (build/upgrade mutates homestead + roster).
/// Does not own a container — all writes route through the hub.
@MainActor
public struct PlayerHomesteadStore {
    private let save: PlayerSaveStore

    public init(save: PlayerSaveStore) {
        self.save = save
    }

    public var state: PlayerHomesteadState {
        get { save.homestead }
        nonmutating set { save.homestead = newValue }
    }

    /// Builds or upgrades a homestead node, updating roster unlocks in the same batch.
    public func buildOrUpgradeNode(_ definition: HomesteadNodeDefinition) -> HomesteadBuildResult {
        var didUpgrade = false
        do {
            try save.performBatchMutation { save in
                var homestead = save.homestead
                var rosterState = save.roster
                guard homestead.buildOrUpgrade(definition, roster: &rosterState) else { return }
                save.homestead = homestead
                save.roster = rosterState
                didUpgrade = true
            }
        } catch {
            return .persistFailed
        }
        return didUpgrade ? .success : .insufficientResources
    }
}
