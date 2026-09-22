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
        switch await homesteadAuthorityGate(upgradeRequest: .upgrade(definition.id, targetTier)) {
        case .local: break
        case .cloudSyncUnsupported: return .cloudSyncUnsupported
        case .cloudUnavailable: return .cloudUnavailable
        case let .cloudUpgrade(outcome):
            switch outcome {
            case .upgraded: return .success
            case .insufficientResources: return .insufficientResources
            case .notAvailable, .progressChanged: return .notAvailable
            default: return .cloudUnavailable
            }
        case .cloudCollected: return .cloudUnavailable
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
        switch await homesteadAuthorityGate() {
        case .local: break
        case .cloudSyncUnsupported: return .cloudSyncUnsupported
        case .cloudUnavailable: return .cloudUnavailable
        case let .cloudCollected(values):
            let amounts = values.map { ResourceAmount($0.key, $0.value) }
                .sorted { $0.resource.rawValue < $1.resource.rawValue }
            return amounts.isEmpty ? .noProduction : .success(amounts)
        case .cloudUpgrade: return .cloudUnavailable
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

enum HomesteadAuthorityGate {
    case local
    case cloudSyncUnsupported
    case cloudUnavailable
    case cloudCollected([HomesteadResource: Int])
    case cloudUpgrade(CloudSaveReceipt.Outcome)
}

@MainActor
extension PlayerSaveStore {
    /// Shared cloud-authority gate for homestead writes. Returns `.local`
    /// when the caller should run the local transaction, otherwise the
    /// cloud outcome to return directly.
    func homesteadAuthorityGate(
        upgradeRequest: CloudSaveRequest.Action? = nil,
    ) async -> HomesteadAuthorityGate {
        guard isCloudSyncEnabled else { return .local }
        guard let cloudSync else { return .cloudSyncUnsupported }
        let ready = await cloudSync.synchronize()
        guard cloudSync.requiresAuthority else { return .local }
        if let upgradeRequest {
            guard ready, let outcome = await cloudSync.perform(upgradeRequest) else {
                return .cloudUnavailable
            }
            return .cloudUpgrade(outcome)
        }
        guard ready, case let .collected(values) = await cloudSync.perform(.collect) else {
            // Collect path only; upgrade callers pass their own request.
            // A non-collect outcome here means the cloud call failed.
            return .cloudUnavailable
        }
        return .cloudCollected(values)
    }
}

enum HomesteadBuildMutation {
    static func apply(
        _ definition: HomesteadNodeDefinition,
        targetTier: Int,
        at date: Date,
        to save: inout PlayerSave,
    ) -> Result<Void, HomesteadBuildFailure> {
        guard let tier = save.homestead.nextTier(for: definition), tier.tier == targetTier else { return .failure(.notAvailable) }
        save.homestead.settleProduction(at: date, roster: save.roster)
        guard save.homestead.canAfford(tier, roster: save.roster) else { return .failure(.insufficientResources) }
        guard save.homestead.buildOrUpgrade(definition, roster: &save.roster) else { return .failure(.notAvailable) }
        return .success(())
    }
}
