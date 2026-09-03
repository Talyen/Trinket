import Foundation
import TrinketContent
import TrinketCore

public enum HomesteadBuildResult: Equatable, Sendable {
    case success
    case insufficientResources
    case notAvailable
    case persistFailed
}

public enum HomesteadCollectionResult: Equatable, Sendable {
    case success([ResourceAmount])
    case noProduction
    case cloudSyncUnsupported
    case persistFailed
}

@MainActor
public extension PlayerSaveStore {
    func buildOrUpgradeNode(
        _ definition: HomesteadNodeDefinition,
        at date: Date = Date(),
    ) -> HomesteadBuildResult {
        guard homestead.isUnlocked(definition),
              homestead.nextTier(for: definition) != nil
        else {
            return .notAvailable
        }

        var buildResult: HomesteadBuildResult = .notAvailable
        guard persistBatch(logging: "Failed to build or upgrade homestead node", { save in
            save.homestead.settleProduction(at: date, roster: save.roster)
            guard let tier = save.homestead.nextTier(for: definition),
                  save.homestead.isUnlocked(definition)
            else {
                buildResult = .notAvailable
                return
            }
            guard save.homestead.canAfford(tier, roster: save.roster) else {
                buildResult = .insufficientResources
                return
            }
            guard save.homestead.buildOrUpgrade(definition, roster: &save.roster) else {
                buildResult = .notAvailable
                return
            }
            buildResult = .success
        }) else {
            return .persistFailed
        }
        return buildResult
    }

    func collectProduction(at date: Date = Date()) -> HomesteadCollectionResult {
        var collected: [ResourceAmount] = []
        guard persistBatch(logging: "Failed to collect homestead production", { save in
            collected = save.homestead.collectProduction(at: date, roster: &save.roster)
        }) else {
            return .persistFailed
        }
        return collected.isEmpty ? .noProduction : .success(collected)
    }
}
