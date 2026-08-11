import Foundation
import TrinketContent
import TrinketCore

/// Thin domain facade over `PlayerSaveStore` for homestead.
/// Owns cross-slice player actions (build/upgrade mutates homestead + roster).
/// Does not own a container — all writes route through the hub.
@MainActor
public struct PlayerHomesteadStore {
    private let save: PlayerSaveStore

    public init(save: PlayerSaveStore) {
        self.save = save
    }

    /// Builds or upgrades a homestead node, updating roster unlocks in the same batch.
    public func buildOrUpgradeNode(
        _ definition: HomesteadNodeDefinition,
        at date: Date = Date()
    ) -> HomesteadBuildResult {
        var didUpgrade = false
        guard save.persistBatch(logging: "Failed to build or upgrade homestead node", { save in
            var homestead = save.homestead
            var rosterState = save.roster
            guard homestead.isUnlocked(definition),
                  let tier = homestead.nextTier(for: definition),
                  homestead.canAfford(tier, roster: rosterState)
            else { return }
            homestead.settleProduction(at: date, roster: rosterState)
            guard homestead.buildOrUpgrade(definition, roster: &rosterState) else { return }
            save.homestead = homestead
            save.roster = rosterState
            didUpgrade = true
        }) else {
            return .persistFailed
        }
        return didUpgrade ? .success : .insufficientResources
    }

    public func collectProduction(at date: Date = Date()) -> HomesteadCollectionResult {
        guard !save.isCloudSyncEnabled else { return .cloudSyncUnsupported }
        var collected: [ResourceAmount] = []
        guard save.persistBatch(logging: "Failed to collect homestead production", { save in
            var homestead = save.homestead
            var roster = save.roster
            collected = homestead.collectProduction(at: date, roster: &roster)
            save.homestead = homestead
            save.roster = roster
        }) else {
            return .persistFailed
        }
        return collected.isEmpty ? .noProduction : .success(collected)
    }
}
