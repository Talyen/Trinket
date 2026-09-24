import TrinketCore

extension CloudSaveMerge {
    static func mergeEconomy(into merged: inout PlayerSave, branches: Branches) {
        let incoming = branches.incoming
        let existing = branches.existing
        let base = branches.base
        let overlappingProduction = base.map {
            incoming.homestead.lastProductionAt > $0.homestead.lastProductionAt
                && existing.homestead.lastProductionAt > $0.homestead.lastProductionAt
        } ?? false
        let overlappingUpgrade = base.map { base in
            HomesteadNodeID.allCases.contains { id in
                incoming.homestead.tier(for: id) > base.homestead.tier(for: id)
                    && existing.homestead.tier(for: id) > base.homestead.tier(for: id)
            }
        } ?? false
        let canCombine = branches.canCombineIndependentRewards
        let repeatedGold = overlappingProduction
            && incoming.roster.gold > (base?.roster.gold ?? 0)
            && existing.roster.gold > (base?.roster.gold ?? 0)
        merged.roster.gold = balance(
            incoming.roster.gold, existing.roster.gold, base: base?.roster.gold,
            combine: canCombine && !repeatedGold,
        )
        for resource in HomesteadResource.allCases where resource != .gold {
            let first = incoming.homestead.resources[resource, default: 0]
            let second = existing.homestead.resources[resource, default: 0]
            let starting = base?.homestead.resources[resource, default: 0]
            let repeated = overlappingProduction && first > (starting ?? 0) && second > (starting ?? 0)
            merged.homestead.resources[resource] = balance(
                first, second, base: starting, combine: canCombine && !overlappingUpgrade && !repeated,
            )
        }
        for (id, tier) in incoming.homestead.nodeTiers.merging(existing.homestead.nodeTiers, uniquingKeysWith: max) {
            merged.homestead.nodeTiers[id] = tier
        }
        merged.homestead.lastProductionAt = max(incoming.homestead.lastProductionAt, existing.homestead.lastProductionAt)
        mergePendingProduction(
            into: &merged, incoming: incoming, existing: existing,
            base: base, overlappingProduction: overlappingProduction,
        )
    }

    private static func mergePendingProduction(
        into merged: inout PlayerSave, incoming: PlayerSave, existing: PlayerSave,
        base: PlayerSave?, overlappingProduction: Bool,
    ) {
        let sameProductionInterval = overlappingProduction && base.map {
            incoming.homestead.lastProductionAt == existing.homestead.lastProductionAt
                && incoming.homestead.nodeTiers == $0.homestead.nodeTiers
                && existing.homestead.nodeTiers == $0.homestead.nodeTiers
        } == true
        for resource in HomesteadResource.allCases {
            let current = incoming.homestead.pendingProduction[resource, default: 0]
            let amount = existing.homestead.pendingProduction[resource, default: 0]
            let baseBalance = resource == .gold ? base?.roster.gold : base?.homestead.resources[resource, default: 0]
            let incomingBalance = resource == .gold ? incoming.roster.gold : incoming.homestead.resources[resource, default: 0]
            let existingBalance = resource == .gold ? existing.roster.gold : existing.homestead.resources[resource, default: 0]
            let collected = overlappingProduction && baseBalance.map {
                incomingBalance > $0 || existingBalance > $0
            } == true
            let pending: Double = if collected || sameProductionInterval {
                min(current, amount)
            } else if let basePending = base?.homestead.pendingProduction[resource, default: 0], current == basePending {
                amount
            } else if let basePending = base?.homestead.pendingProduction[resource, default: 0], amount == basePending {
                current
            } else {
                max(current, amount)
            }
            if pending > 0 {
                merged.homestead.pendingProduction[resource] = pending
            } else {
                merged.homestead.pendingProduction.removeValue(forKey: resource)
            }
        }
    }

    private static func balance(_ lhs: Int, _ rhs: Int, base: Int?, combine: Bool) -> Int {
        guard combine, let base else { return max(lhs, rhs) }
        let left = SaturatedArithmetic.saturatingSub(lhs, base)
        let right = SaturatedArithmetic.saturatingSub(rhs, base)
        return max(0, SaturatedArithmetic.saturatingAdd(base, SaturatedArithmetic.saturatingAdd(left, right)))
    }
}
