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
        _ definition: HomesteadNodeDefinition,
        targetTier: Int,
        at date: Date = Date(),
    ) async -> HomesteadBuildResult {
        let result = await retryingSaveTransaction {
            try prepareLocalProduction()
            return persistTransaction(logging: "Failed to build or upgrade homestead node") { save, recordReceipt in
                HomesteadBuildMutation.apply(definition, targetTier: targetTier, at: date, to: &save, recordReceipt: recordReceipt)
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
            return persistTransaction(logging: "Failed to collect homestead production") { save, recordReceipt -> Result<
                [ResourceAmount],
                Never,
            > in
                save.homestead.settleProduction(at: date, gold: save.roster.gold)
                let collection = SaveEconomicReceipt.Collection(
                    pending: save.homestead.pendingProduction, nodeTiers: save.homestead.nodeTiers,
                    date: save.homestead.lastProductionAt, gold: save.roster.gold,
                )
                let collected = save.homestead.collectProduction(at: date, gold: &save.roster.gold)
                let amounts = Dictionary(uniqueKeysWithValues: collected.map { ($0.resource, $0.quantity) })
                if !collected.isEmpty {
                    recordReceipt(SaveEconomicReceipt(kind: .collection(collection), effects: .committed(
                        gold: amounts[.gold, default: 0], materials: amounts.filter { $0.key != .gold },
                    )))
                }
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
    static func apply(
        _ definition: HomesteadNodeDefinition,
        targetTier: Int,
        at date: Date,
        to save: inout PlayerSave,
        recordReceipt: (SaveEconomicReceipt) -> Void,
    ) -> Result<Void, HomesteadBuildFailure> {
        guard let tier = save.homestead.nextTier(for: definition), tier.tier == targetTier else { return .failure(.notAvailable) }
        save.homestead.settleProduction(at: date, gold: save.roster.gold)
        guard save.homestead.canAfford(tier, gold: save.roster.gold) else { return .failure(.insufficientResources) }
        guard save.homestead.buildOrUpgrade(definition, gold: &save.roster.gold) else { return .failure(.notAvailable) }
        var costs: [HomesteadResource: Int] = [:]
        for amount in tier.cost {
            costs[amount.resource, default: 0] -= amount.quantity
        }
        recordReceipt(SaveEconomicReceipt(kind: .upgrade(definition.id, tier.tier), effects: .committed(
            gold: costs[.gold, default: 0], materials: costs.filter { $0.key != .gold },
        )))
        return .success(())
    }
}
