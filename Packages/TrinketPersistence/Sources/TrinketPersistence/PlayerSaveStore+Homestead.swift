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
    case persistFailed
}

@MainActor
public extension PlayerSaveStore {
    func buildOrUpgradeNode(
        _ definition: HomesteadNodeDefinition,
        targetTier: Int,
        at date: Date = Date(),
    ) async -> HomesteadBuildResult {
        await Task.yield()
        guard prepareLocalProduction() else { return .persistFailed }
        let result = persistTransaction(logging: "Failed to build or upgrade homestead node") { save, recordReceipt -> Result<
            Void,
            HomesteadBuildFailure,
        > in
            HomesteadBuildMutation.apply(definition, targetTier: targetTier, at: date, to: &save, recordReceipt: recordReceipt)
        }
        switch result {
        case .committed: return .success
        case .rejected(.notAvailable): return .notAvailable
        case .rejected(.insufficientResources): return .insufficientResources
        case .persistFailed: return .persistFailed
        }
    }

    func collectProduction(at date: Date = Date()) async -> HomesteadCollectionResult {
        await Task.yield()
        guard prepareLocalProduction() else { return .persistFailed }
        var collected: [ResourceAmount] = []
        guard persistBatch(logging: "Failed to collect homestead production", { save, recordReceipt in
            save.homestead.settleProduction(at: date, roster: save.roster)
            let collection = SaveEconomicReceipt.Collection(
                pending: save.homestead.pendingProduction, nodeTiers: save.homestead.nodeTiers,
                date: save.homestead.lastProductionAt, gold: save.roster.gold,
            )
            collected = save.homestead.collectProduction(at: date, roster: &save.roster)
            let amounts = Dictionary(uniqueKeysWithValues: collected.map { ($0.resource, $0.quantity) })
            if !collected.isEmpty {
                recordReceipt(SaveEconomicReceipt(kind: .collection(collection), effects: .committed(
                    gold: amounts[.gold, default: 0], materials: amounts.filter { $0.key != .gold },
                )))
            }
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
        recordReceipt: (SaveEconomicReceipt) -> Void = { _ in },
    ) -> Result<Void, HomesteadBuildFailure> {
        guard let tier = save.homestead.nextTier(for: definition), tier.tier == targetTier else { return .failure(.notAvailable) }
        save.homestead.settleProduction(at: date, roster: save.roster)
        guard save.homestead.canAfford(tier, roster: save.roster) else { return .failure(.insufficientResources) }
        guard save.homestead.buildOrUpgrade(definition, roster: &save.roster) else { return .failure(.notAvailable) }
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
