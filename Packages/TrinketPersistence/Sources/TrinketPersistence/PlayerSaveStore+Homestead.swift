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
            var homestead = save.homestead
            var rosterState = save.roster
            homestead.settleProduction(at: date, roster: rosterState)
            guard homestead.buildOrUpgrade(definition, roster: &rosterState) else { return }
            save.homestead = homestead
            save.roster = rosterState
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
