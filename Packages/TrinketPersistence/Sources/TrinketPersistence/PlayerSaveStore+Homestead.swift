import Foundation
import TrinketContent
import TrinketCore

public enum HomesteadBuildResult: Equatable, Sendable {
    case success
    case insufficientResources
    case notAvailable
    case persistFailed
    case invalidated
}

public enum HomesteadCollectionResult: Equatable, Sendable {
    case success([ResourceAmount])
    case noProduction
    case persistFailed
    case invalidated
}

@MainActor
public extension PlayerSaveStore {
    func buildOrUpgradeNode(
        _ nodeID: HomesteadNodeID,
        targetTier: Int,
        at date: Date = Date(),
    ) async -> HomesteadBuildResult {
        let result = await retryingSaveTransaction {
            try prepareLocalProduction()
            return persistAction(kind: .upgrade(nodeID, targetTier), logging: "Failed to build or upgrade homestead node") { save in
                HomesteadBuildMutation.apply(nodeID, targetTier: targetTier, at: date, to: &save)
            }
        }
        switch result {
        case .committed: return .success
        case .rejected(.notAvailable): return .notAvailable
        case .rejected(.insufficientResources): return .insufficientResources
        case .persistFailed: return .persistFailed
        case nil: return .invalidated
        }
    }

    func collectProduction(at date: Date = Date()) async -> HomesteadCollectionResult {
        let result = await retryingSaveTransaction {
            try prepareLocalProduction()
            var settled = currentSave.homestead
            settled.settleProduction(at: date, gold: currentSave.roster.gold)
            let collection = SaveEconomicReceipt.Collection(
                pending: settled.pendingProduction, nodeTiers: settled.nodeTiers,
                date: settled.lastProductionAt, gold: currentSave.roster.gold,
            )
            return persistAction(kind: .collection(collection), logging: "Failed to collect homestead production") { save -> Result<
                [ResourceAmount],
                Never,
            > in
                save.homestead.settleProduction(at: date, gold: save.roster.gold)
                let collected = save.homestead.collectProduction(at: date, gold: &save.roster.gold)
                return .success(collected)
            }
        }
        switch result {
        case let .committed(collected): return collected.isEmpty ? .noProduction : .success(collected)
        case .persistFailed: return .persistFailed
        case nil: return .invalidated
        }
    }
}

enum HomesteadBuildFailure: Error {
    case notAvailable
    case insufficientResources
}

enum HomesteadBuildMutation {
    /// Resolve price and tier from Content at admission; display values never authorize a purchase.
    static func apply(
        _ nodeID: HomesteadNodeID,
        targetTier: Int,
        at date: Date,
        to save: inout PlayerSave,
    ) -> Result<Void, HomesteadBuildFailure> {
        guard let definition = GameContent.homesteadNode(matching: nodeID),
              let tier = save.homestead.nextTier(for: definition), tier.tier == targetTier else { return .failure(.notAvailable) }
        save.homestead.settleProduction(at: date, gold: save.roster.gold)
        guard save.homestead.canAfford(tier, gold: save.roster.gold) else { return .failure(.insufficientResources) }
        guard save.homestead.buildOrUpgrade(definition, gold: &save.roster.gold) else { return .failure(.notAvailable) }
        return .success(())
    }
}
