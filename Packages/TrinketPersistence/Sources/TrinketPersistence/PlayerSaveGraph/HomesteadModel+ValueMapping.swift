import Foundation
import SwiftData
import TrinketContent
import TrinketCore

extension HomesteadModel {
    func toPlayerHomesteadState() -> PlayerHomesteadState {
        var resolvedResources: [HomesteadResource: Int] = [:]
        for balance in resources ?? [] {
            guard let resource = HomesteadResource.resolving(resourceID: balance.resourceID), resource != .gold else { continue }
            resolvedResources[resource] = balance.quantity
        }
        var resolvedPendingProduction: [HomesteadResource: Double] = [:]
        for pending in pendingProduction ?? [] {
            guard let resource = HomesteadResource.resolving(resourceID: pending.resourceID),
                  pending.quantity.isFinite, pending.quantity > 0
            else { continue }
            resolvedPendingProduction[resource] = pending.quantity
        }
        var resolvedNodeTiers: [HomesteadNodeID: Int] = [:]
        for tierModel in nodeTiers ?? [] {
            guard let nodeID = HomesteadNodeID.resolving(nodeID: tierModel.nodeID) else { continue }
            resolvedNodeTiers[nodeID] = max(resolvedNodeTiers[nodeID, default: 0], tierModel.tier)
        }
        return PlayerHomesteadState(
            resources: resolvedResources,
            nodeTiers: resolvedNodeTiers,
            pendingProduction: resolvedPendingProduction,
            lastProductionAt: lastProductionAt,
            rewardRemainders: goldRewardRemainder == 0 && gemsRewardRemainder == 0 ? nil
                : .init(gold: goldRewardRemainder, gems: gemsRewardRemainder),
        )
    }

    func update(from homestead: PlayerHomesteadState, context: ModelContext?) {
        lastProductionAt = homestead.lastProductionAt
        goldRewardRemainder = homestead.rewardRemainders?.gold ?? 0
        gemsRewardRemainder = homestead.rewardRemainders?.gems ?? 0

        let resourceValues = homestead.resources.sorted { $0.key.rawValue < $1.key.rawValue }
        resources = reconcileModels(
            existing: resources ?? [],
            values: resourceValues,
            existingKey: \.resourceID,
            valueKey: { $0.key.rawValue },
            make: { HomesteadResourceBalanceModel() },
            update: { model, value in
                model.resourceID = value.key.rawValue
                model.quantity = value.value
            },
            link: { $0.homestead = self },
            context: context,
        )

        let pendingValues = homestead.validPendingProduction.sorted { $0.key.rawValue < $1.key.rawValue }
        pendingProduction = reconcileModels(
            existing: pendingProduction ?? [],
            values: pendingValues,
            existingKey: \.resourceID,
            valueKey: { $0.key.rawValue },
            make: { HomesteadPendingProductionModel() },
            update: { model, value in
                model.resourceID = value.key.rawValue
                model.quantity = value.value
            },
            link: { $0.homestead = self },
            context: context,
        )

        let tierValues = homestead.nodeTiers.sorted { $0.key.rawValue < $1.key.rawValue }
        nodeTiers = reconcileModels(
            existing: nodeTiers ?? [],
            values: tierValues,
            existingKey: \.nodeID,
            valueKey: { $0.key.rawValue },
            make: { HomesteadNodeTierModel() },
            update: { model, value in
                model.nodeID = value.key.rawValue
                model.tier = value.value
            },
            link: { $0.homestead = self },
            context: context,
        )
    }
}
