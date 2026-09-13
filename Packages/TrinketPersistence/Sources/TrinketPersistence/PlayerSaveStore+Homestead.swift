import Foundation
import TrinketContent
import TrinketCore

public enum HomesteadBuildResult: Equatable, Sendable {
    case success
    case insufficientResources
    case notAvailable
    case cloudSyncUnsupported
    case cloudUnavailable
    case persistFailed
}

public enum HomesteadCollectionResult: Equatable, Sendable {
    case success([ResourceAmount])
    case noProduction
    case cloudSyncUnsupported
    case cloudUnavailable
    case persistFailed
}

@MainActor
public extension PlayerSaveStore {
    func buildOrUpgradeNode(
        _ definition: HomesteadNodeDefinition,
        targetTier: Int,
        at date: Date = Date(),
    ) async -> HomesteadBuildResult {
        if isCloudSyncEnabled {
            guard let cloudSync else { return .cloudSyncUnsupported }
            let ready = await cloudSync.synchronize()
            if cloudSync.requiresAuthority {
                guard ready, let outcome = await cloudSync.perform(.upgrade(definition.id, targetTier)) else {
                    return .cloudUnavailable
                }
                switch outcome {
                case .upgraded: return .success
                case .insufficientResources: return .insufficientResources
                case .notAvailable, .progressChanged: return .notAvailable
                default: return .cloudUnavailable
                }
            }
        }
        guard prepareLocalProduction() else { return .persistFailed }
        let result = persistTransaction(logging: "Failed to build or upgrade homestead node") { save -> Result<
            Void,
            HomesteadBuildFailure,
        > in
            HomesteadBuildMutation.apply(definition, targetTier: targetTier, at: date, to: &save)
        }
        switch result {
        case .committed: return .success
        case .rejected(.notAvailable): return .notAvailable
        case .rejected(.insufficientResources): return .insufficientResources
        case .persistFailed: return .persistFailed
        }
    }

    func collectProduction(at date: Date = Date()) async -> HomesteadCollectionResult {
        if isCloudSyncEnabled {
            guard let cloudSync else { return .cloudSyncUnsupported }
            let ready = await cloudSync.synchronize()
            if cloudSync.requiresAuthority {
                guard ready, case let .collected(values) = await cloudSync.perform(.collect) else {
                    return .cloudUnavailable
                }
                let amounts = values.map { ResourceAmount($0.key, $0.value) }
                    .sorted { $0.resource.rawValue < $1.resource.rawValue }
                return amounts.isEmpty ? .noProduction : .success(amounts)
            }
        }
        guard prepareLocalProduction() else { return .persistFailed }
        var collected: [ResourceAmount] = []
        guard persistBatch(logging: "Failed to collect homestead production", { save in
            collected = save.homestead.collectProduction(at: date, roster: &save.roster)
        }) else {
            return .persistFailed
        }
        return collected.isEmpty ? .noProduction : .success(collected)
    }
}

enum HomesteadBuildFailure: Error {
    case notAvailable
    case insufficientResources
}

enum HomesteadBuildMutation {
    static func apply(
        _ definition: HomesteadNodeDefinition,
        targetTier: Int,
        at date: Date,
        to save: inout PlayerSave,
    ) -> Result<Void, HomesteadBuildFailure> {
        guard let tier = save.homestead.nextTier(for: definition), tier.tier == targetTier,
              save.homestead.isUnlocked(definition) else { return .failure(.notAvailable) }
        save.homestead.settleProduction(at: date, roster: save.roster)
        guard save.homestead.canAfford(tier, roster: save.roster) else { return .failure(.insufficientResources) }
        guard save.homestead.buildOrUpgrade(definition, roster: &save.roster) else { return .failure(.notAvailable) }
        return .success(())
    }
}
