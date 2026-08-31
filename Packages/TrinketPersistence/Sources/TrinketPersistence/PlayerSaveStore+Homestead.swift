import Foundation
import TrinketContent
import TrinketCore

@MainActor
public extension PlayerSaveStore {
    func buildOrUpgradeNode(
        _ definition: HomesteadNodeDefinition,
        at date: Date = Date(),
    ) -> HomesteadBuildResult {
        let homesteadState = homestead
        let rosterState = roster
        guard homesteadState.isUnlocked(definition),
              let tier = homesteadState.nextTier(for: definition)
        else {
            return .notAvailable
        }
        guard homesteadState.canAfford(tier, roster: rosterState) else {
            return .insufficientResources
        }

        var didUpgrade = false
        guard persistBatch(logging: "Failed to build or upgrade homestead node", { save in
            save.homestead.settleProduction(at: date, roster: save.roster)
            guard save.homestead.buildOrUpgrade(definition, roster: &save.roster) else { return }
            didUpgrade = true
        }) else {
            return .persistFailed
        }
        return didUpgrade ? .success : .notAvailable
    }

    func collectProduction(at date: Date = Date()) -> HomesteadCollectionResult {
        guard !isCloudSyncEnabled else { return .cloudSyncUnsupported }
        var collected: [ResourceAmount] = []
        guard persistBatch(logging: "Failed to collect homestead production", { save in
            collected = save.homestead.collectProduction(at: date, roster: &save.roster)
        }) else {
            return .persistFailed
        }
        return collected.isEmpty ? .noProduction : .success(collected)
    }
}
