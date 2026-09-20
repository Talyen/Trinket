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
        )
    }

    func update(from homestead: PlayerHomesteadState, context: ModelContext?) {
        lastProductionAt = homestead.lastProductionAt

        let resourceValues = homestead.resources
            .map { (resourceID: $0.key.rawValue, quantity: $0.value) }
            .sorted { $0.resourceID < $1.resourceID }
        resources = reconcileModels(
            existing: resources ?? [],
            values: resourceValues,
            existingKey: \.resourceID,
            valueKey: { $0.resourceID },
            make: { _ in HomesteadResourceBalanceModel() },
            update: { model, value in
                model.resourceID = value.resourceID
                model.quantity = value.quantity
            },
            link: { $0.homestead = self },
            context: context,
        )

        let pendingValues = homestead.validPendingProduction
            .map { (resourceID: $0.key.rawValue, quantity: $0.value) }
            .sorted { $0.resourceID < $1.resourceID }
        pendingProduction = reconcileModels(
            existing: pendingProduction ?? [],
            values: pendingValues,
            existingKey: \.resourceID,
            valueKey: { $0.resourceID },
            make: { _ in HomesteadPendingProductionModel() },
            update: { model, value in
                model.resourceID = value.resourceID
                model.quantity = value.quantity
            },
            link: { $0.homestead = self },
            context: context,
        )

        let tierValues = homestead.nodeTiers
            .map { (nodeID: $0.key.rawValue, tier: $0.value) }
            .sorted { $0.nodeID < $1.nodeID }
        nodeTiers = reconcileModels(
            existing: nodeTiers ?? [],
            values: tierValues,
            existingKey: \.nodeID,
            valueKey: { $0.nodeID },
            make: { _ in HomesteadNodeTierModel() },
            update: { model, value in
                model.nodeID = value.nodeID
                model.tier = value.tier
            },
            link: { $0.homestead = self },
            context: context,
        )
    }
}
