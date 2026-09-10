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
        targetTier: Int,
        at date: Date = Date(),
    ) -> HomesteadBuildResult {
        let result = persistTransaction(logging: "Failed to build or upgrade homestead node") { save -> Result<
            Void,
            HomesteadBuildFailure,
        > in
            guard let tier = save.homestead.nextTier(for: definition), tier.tier == targetTier,
                  save.homestead.isUnlocked(definition) else { return .failure(.notAvailable) }
            save.homestead.settleProduction(at: date, roster: save.roster)
            guard save.homestead.canAfford(tier, roster: save.roster) else { return .failure(.insufficientResources) }
            guard save.homestead.buildOrUpgrade(definition, roster: &save.roster) else { return .failure(.notAvailable) }
            return .success(())
        }
        switch result {
        case .committed: return .success
        case .rejected(.notAvailable): return .notAvailable
        case .rejected(.insufficientResources): return .insufficientResources
        case .persistFailed: return .persistFailed
        }
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

private enum HomesteadBuildFailure: Error {
    case notAvailable
    case insufficientResources
}
