import TrinketContent
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
        let producedResources = overlappingProduction ? productionResources(
            in: [base?.homestead, incoming.homestead, existing.homestead].compactMap(\.self),
        ) : []
        let overlappingUpgrade = base.map { base in
            HomesteadNodeID.allCases.contains { id in
                incoming.homestead.tier(for: id) > base.homestead.tier(for: id)
                    && existing.homestead.tier(for: id) > base.homestead.tier(for: id)
            }
        } ?? false
        let canCombine = branches.canCombineIndependentRewards
        let repeatedGold = overlappingProduction
            && producedResources.contains(.gold)
            && incoming.roster.gold > (base?.roster.gold ?? 0)
            && existing.roster.gold > (base?.roster.gold ?? 0)
        var combinedResources: Set<HomesteadResource> = []
        if canCombine, !repeatedGold {
            combinedResources.insert(.gold)
        }
        merged.roster.gold = balance(
            incoming.roster.gold, existing.roster.gold, base: base?.roster.gold,
            combine: canCombine && !repeatedGold,
        )
        for resource in HomesteadResource.allCases where resource != .gold {
            let first = incoming.homestead.resources[resource, default: 0]
            let second = existing.homestead.resources[resource, default: 0]
            let starting = base?.homestead.resources[resource, default: 0]
            let repeated = overlappingProduction && producedResources.contains(resource)
                && first > (starting ?? 0) && second > (starting ?? 0)
            if canCombine, !overlappingUpgrade, !repeated {
                combinedResources.insert(resource)
            }
            merged.homestead.resources[resource] = balance(
                first, second, base: starting, combine: canCombine && !overlappingUpgrade && !repeated,
            )
        }
        mergeRewardRemainders(into: &merged, branches: branches, combinedResources: combinedResources)
        for (id, tier) in incoming.homestead.nodeTiers.merging(existing.homestead.nodeTiers, uniquingKeysWith: max) {
            merged.homestead.nodeTiers[id] = tier
        }
        merged.homestead.lastProductionAt = max(incoming.homestead.lastProductionAt, existing.homestead.lastProductionAt)
        mergePendingProduction(
            into: &merged, incoming: incoming, existing: existing,
            base: base, overlappingProduction: overlappingProduction,
        )
    }

    private static func productionResources(in homesteads: [PlayerHomesteadState]) -> Set<HomesteadResource> {
        var resources: Set<HomesteadResource> = []
        for homestead in homesteads {
            // Pending credit can still be collected without an active producer.
            resources.formUnion(homestead.validPendingProduction.keys)
            for (id, activeTier) in homestead.nodeTiers where activeTier > 0 {
                guard let tier = GameContent.homesteadNode(matching: id)?.tier(activeTier) else { continue }
                resources.formUnion(tier.production.filter { $0.quantity > 0 }.map(\.resource))
            }
        }
        return resources
    }

    private static func mergeRewardRemainders(
        into merged: inout PlayerSave, branches: Branches, combinedResources: Set<HomesteadResource>,
    ) {
        let first = branches.incoming.homestead.rewardRemainders ?? .zero
        let second = branches.existing.homestead.rewardRemainders ?? .zero
        guard branches.canCombineIndependentRewards, let base = branches.base else {
            merged.homestead.rewardRemainders = branches.selected(\.homestead.rewardRemainders)
            return
        }
        let starting = base.homestead.rewardRemainders ?? .zero
        var result = HomesteadRewardRemainders.zero
        for resource in [HomesteadResource.gold, .gems] {
            if !combinedResources.contains(resource) {
                let selected = branches.selected { save in
                    let remainders = save.homestead.rewardRemainders ?? .zero
                    return resource == .gold ? remainders.gold : remainders.gems
                }
                if resource == .gold {
                    result.gold = selected
                } else {
                    result.gems = selected
                }
                continue
            }
            let total = resource == .gold ? first.gold + second.gold - starting.gold
                : first.gems + second.gems - starting.gems
            // A negative carry means both branches already paid the same baseline fraction.
            let correction = total < 0 ? -1 : total / 100
            let remainder = (total % 100 + 100) % 100
            if resource == .gold {
                result.gold = remainder
                merged.roster.gold = min(PlayerRosterState.maxGoldBalance, max(0, merged.roster.gold + correction))
            } else {
                result.gems = remainder
                merged.homestead.resources[.gems] = max(0, SaturatedArithmetic.saturatingAdd(
                    merged.homestead.resources[.gems, default: 0], correction,
                ))
            }
        }
        merged.homestead.rewardRemainders = result == .zero ? nil : result
    }

    private static func mergePendingProduction(
        into merged: inout PlayerSave, incoming: PlayerSave, existing: PlayerSave,
        base: PlayerSave?, overlappingProduction: Bool,
    ) {
        var incomingProduction = incoming.homestead
        var existingProduction = existing.homestead
        if overlappingProduction {
            // Compare uncollected credit at one cursor; an earlier collection must
            // not erase production earned after it on the later branch.
            incomingProduction.settleProduction(at: merged.homestead.lastProductionAt, roster: incoming.roster)
            existingProduction.settleProduction(at: merged.homestead.lastProductionAt, roster: existing.roster)
        }
        let sameProductionInterval = overlappingProduction && base.map {
            incoming.homestead.lastProductionAt == existing.homestead.lastProductionAt
                && incoming.homestead.nodeTiers == $0.homestead.nodeTiers
                && existing.homestead.nodeTiers == $0.homestead.nodeTiers
        } == true
        for resource in HomesteadResource.allCases {
            let current = incomingProduction.pendingProduction[resource, default: 0]
            let amount = existingProduction.pendingProduction[resource, default: 0]
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
        guard let base else { return max(lhs, rhs) }
        if lhs == base {
            return rhs
        }
        if rhs == base {
            return lhs
        }
        guard combine else {
            return max(lhs, rhs)
        }
        let left = SaturatedArithmetic.saturatingSub(lhs, base)
        let right = SaturatedArithmetic.saturatingSub(rhs, base)
        return max(0, SaturatedArithmetic.saturatingAdd(base, SaturatedArithmetic.saturatingAdd(left, right)))
    }
}
