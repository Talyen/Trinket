import TrinketContent
import TrinketCore

/// Committed effects of one journal mutation. The enclosing mutation ID is its
/// retry identity; claim receipts identify payouts shared by different devices.
struct CloudEconomicAction: Codable, Equatable, Sendable {
    enum Claim: Codable, Equatable, Sendable {
        case contract(String)
        case journey(String)
        case spire(id: String, floor: Int)
        case labyrinth(seed: UInt64, nodeID: String)
        case voyage(runID: String, nodeID: String)
        case salvage(String)

        func isClaimed(in save: PlayerSave, since before: PlayerSave) -> Bool {
            switch self {
            case let .contract(id):
                if let completed = save.contracts.completedOfferIDs {
                    completed.contains(id)
                } else {
                    before.contracts.offers.contains { $0.id == id } && !save.contracts.offers.contains { $0.id == id }
                }
            case let .journey(id): save.journey.claimedRewardStageIDs.contains(id)
            case let .spire(id, floor): save.spires.highestClearedFloor(for: id) >= floor
            case let .labyrinth(seed, nodeID):
                save.labyrinth.worldSeed == seed && save.labyrinth.nodes[nodeID]?.isCleared == true
            case let .voyage(runID, nodeID):
                save.voyage.completedRunIDs?.contains(runID) == true
                    || save.voyage.node(runID: runID, nodeID: nodeID)?.isCleared == true
            case let .salvage(id): !save.inventory.items.contains { $0.id == id }
            }
        }
    }

    var formatVersion = 1
    let claim: Claim?
    let gold: Int
    let materials: [HomesteadResource: Int]
    let experience: [String: Int]
    let goldRemainder: Int
    let gemsRemainder: Int

    func validate() throws {
        guard formatVersion == 1, materials[.gold] == nil,
              experience.values.allSatisfy({ $0 >= 0 }),
              (-99 ... 99).contains(goldRemainder), (-99 ... 99).contains(gemsRemainder)
        else { throw CloudSaveError.unsupportedSave }
    }

    static func record(from before: PlayerSave, to after: PlayerSave) -> Self? {
        // Production and upgrades retain their interval/cost reconciliation.
        // A payout may settle production, but must not consume pending credit.
        guard before.homestead.nodeTiers == after.homestead.nodeTiers else { return nil }
        var settled = before.homestead
        settled.settleProduction(at: after.homestead.lastProductionAt, roster: before.roster)
        guard !HomesteadResource.allCases.contains(where: {
            after.homestead.pendingProduction[$0, default: 0] < settled.pendingProduction[$0, default: 0]
        }), let claims = claims(from: before, to: after), claims.count <= 1 else { return nil }

        var experience: [String: Int] = [:]
        for (id, progression) in after.roster.progressions {
            let starting = (before.roster.progressions[id] ?? .initial).totalEarnedExperience
            let delta = SaturatedArithmetic.saturatingSub(progression.totalEarnedExperience, starting)
            guard delta >= 0 else { return nil }
            if delta != 0 {
                experience[id] = delta
            }
        }
        var materials: [HomesteadResource: Int] = [:]
        for resource in HomesteadResource.allCases where resource != .gold {
            let delta = SaturatedArithmetic.saturatingSub(
                after.homestead.resources[resource, default: 0], before.homestead.resources[resource, default: 0],
            )
            if delta != 0 {
                materials[resource] = delta
            }
        }
        let first = before.homestead.rewardRemainders ?? .zero
        let last = after.homestead.rewardRemainders ?? .zero
        let action = Self(
            claim: claims.first, gold: after.roster.gold - before.roster.gold,
            materials: materials, experience: experience,
            goldRemainder: last.gold - first.gold, gemsRemainder: last.gems - first.gems,
        )
        return action.gold != 0 || !materials.isEmpty || !experience.isEmpty
            || action.goldRemainder != 0 || action.gemsRemainder != 0 ? action : nil
    }

    func replay(onto merged: inout PlayerSave, existing: PlayerSave, before: PlayerSave) throws {
        try validate()
        // Snapshot reconciliation still owns inventory, routes and unlocks.
        // Replace its economic result with this action's effects only.
        merged.roster.gold = existing.roster.gold
        merged.homestead.resources = existing.homestead.resources
        merged.homestead.rewardRemainders = existing.homestead.rewardRemainders
        let duplicate = claim?.isClaimed(in: existing, since: before) == true
        for (id, delta) in experience {
            let starting = existing.roster.progressions[id] ?? .initial
            merged.roster.progressions[id] = duplicate ? starting : starting.addingExperience(delta)
        }
        guard !duplicate else { return }
        let starting = existing.homestead.rewardRemainders ?? .zero
        let goldCarry = replayRemainder(starting.gold, delta: goldRemainder)
        let gemsCarry = replayRemainder(starting.gems, delta: gemsRemainder)
        merged.roster.gold = SaturatedArithmetic.saturatingAdd(
            SaturatedArithmetic.saturatingAdd(existing.roster.gold, gold), goldCarry.correction,
        )
        for (resource, delta) in materials where resource != .gems {
            merged.homestead.resources[resource] = max(0, SaturatedArithmetic.saturatingAdd(
                existing.homestead.resources[resource, default: 0], delta,
            ))
        }
        if materials[.gems] != nil || gemsCarry.correction != 0 {
            merged.homestead.resources[.gems] = max(0, SaturatedArithmetic.saturatingAdd(
                SaturatedArithmetic.saturatingAdd(existing.homestead.resources[.gems, default: 0], materials[.gems, default: 0]),
                gemsCarry.correction,
            ))
        }
        var remainders = starting
        remainders.gold = goldCarry.remainder
        remainders.gems = gemsCarry.remainder
        merged.homestead.rewardRemainders = remainders == .zero ? nil : remainders
    }

    private func replayRemainder(_ starting: Int, delta: Int) -> (remainder: Int, correction: Int) {
        let total = starting + delta
        return ((total % 100 + 100) % 100, total < 0 ? -1 : total / 100)
    }

    private static func claims(from before: PlayerSave, to after: PlayerSave) -> [Claim]? {
        // Multiple payouts in a public batch, noncombat choices, and Shop
        // item/price conflicts still need the legacy snapshot rules.
        guard !CloudSaveMerge.hasSharedShopPurchase(incoming: after, existing: after, base: before) else { return nil }
        var result = (after.contracts.completedOfferIDs ?? []).subtracting(before.contracts.completedOfferIDs ?? [])
            .map(Claim.contract)
        for id in after.journey.claimedRewardStageIDs.subtracting(before.journey.claimedRewardStageIDs) {
            guard GameContent.stage(id: id)?.encounter.isCombat == true else { return nil }
            result.append(.journey(id))
        }
        for (id, floor) in after.spires.highestClearedFloorBySpireID {
            let starting = before.spires.highestClearedFloor(for: id)
            guard floor <= starting + 1 else { return nil }
            if floor > starting {
                result.append(.spire(id: id, floor: floor))
            }
        }
        for node in after.labyrinth.nodes.values where node.isCleared && before.labyrinth.nodes[node.id]?.isCleared != true {
            guard node.type.isCombat else { return nil }
            result.append(.labyrinth(seed: after.labyrinth.worldSeed, nodeID: node.id))
        }
        let completedRuns = (after.voyage.completedRunIDs ?? []).subtracting(before.voyage.completedRunIDs ?? [])
        for run in [after.voyage.activeRun, before.voyage.activeRun].compactMap(\.self) {
            for node in run.nodes where before.voyage.node(runID: run.id, nodeID: node.id)?.isCleared != true
                && (after.voyage.node(runID: run.id, nodeID: node.id)?.isCleared == true || completedRuns.contains(run.id)) {
                guard node.type.isCombat else { return nil }
                let claim = Claim.voyage(runID: run.id, nodeID: node.id)
                if !result.contains(claim) {
                    result.append(claim)
                }
            }
        }
        if !completedRuns.isEmpty, !result.contains(where: {
            if case let .voyage(runID, _) = $0 {
                completedRuns.contains(runID)
            } else {
                false
            }
        }) {
            return nil
        }
        let remainingItems = Set(after.inventory.items.map(\.id))
        for item in before.inventory.items where ItemSalvage.isEligible(item) && !remainingItems.contains(item.id) {
            result.append(.salvage(item.id))
        }
        return result
    }
}
