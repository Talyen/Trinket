import TrinketContent
import TrinketCore

/// Per-resource credit coordinates within a reset epoch. Contiguous claims merge
/// into one range; gaps survive out-of-order device uploads. Spending cannot hide
/// collections, and replay never infers them from wallet balances.
struct CloudProductionClaims: Codable, Equatable, Sendable {
    struct Interval: Codable, Equatable, Sendable {
        let start: UInt64
        let end: UInt64
    }

    var resources: [HomesteadResource: [Interval]] = [:]

    var positions: [HomesteadResource: UInt64] {
        resources.mapValues { $0.last?.end ?? 0 }
    }

    func validate() throws {
        for intervals in resources.values {
            var previous: UInt64?
            for interval in intervals {
                guard interval.start < interval.end,
                      previous.map({ $0 < interval.start }) ?? true
                else { throw CloudSaveError.unsupportedSave }
                previous = interval.end
            }
        }
    }

    func covered(_ resource: HomesteadResource, after start: UInt64) -> UInt64 {
        resources[resource, default: []].reduce(0) { total, interval in
            total + (interval.end > start ? interval.end - max(start, interval.start) : 0)
        }
    }

    mutating func claim(_ resource: HomesteadResource, start: UInt64, quantity: Int) -> Int {
        let end = start + UInt64(quantity)
        var intervals = resources[resource, default: []]
        let overlaps = intervals.reduce(UInt64(0)) { total, interval in
            let lower = max(start, interval.start)
            let upper = min(end, interval.end)
            return total + (upper > lower ? upper - lower : 0)
        }
        // Validated history is already sorted; insert without sorting it again.
        let insertion = intervals.firstIndex { $0.start > start } ?? intervals.endIndex
        intervals.insert(Interval(start: start, end: end), at: insertion)
        var merged: [Interval] = []
        for interval in intervals {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = Interval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        resources[resource] = merged
        return quantity - Int(overlaps)
    }

    mutating func replay(_ receipt: SaveEconomicReceipt, onto save: inout PlayerSave) throws {
        guard case let .collection(collection) = receipt.kind, let positions = collection.positions else { return }
        var credit = PlayerHomesteadState(
            resources: [:], nodeTiers: collection.nodeTiers, pendingProduction: collection.pending, lastProductionAt: collection.date,
        )
        var roster = save.roster
        roster.gold = collection.gold
        credit.settleProduction(at: save.homestead.lastProductionAt, roster: roster)
        for (resource, amount) in receipt.collectionAmounts {
            guard let start = positions[resource] else { throw CloudSaveError.unsupportedSave }
            let alreadyCollected = covered(resource, after: start)
            let available = max(0, credit.pendingProduction[resource, default: 0] - Double(alreadyCollected))
            let accepted = claim(resource, start: start, quantity: amount)
            let pending = max(save.homestead.pendingProduction[resource, default: 0], available) - Double(accepted)
            if pending > 0 {
                save.homestead.pendingProduction[resource] = pending
            } else {
                save.homestead.pendingProduction.removeValue(forKey: resource)
            }
            if resource == .gold {
                save.roster.gold = min(PlayerRosterState.maxGoldBalance, SaturatedArithmetic.saturatingAdd(save.roster.gold, accepted))
            } else {
                save.homestead.resources[resource] = SaturatedArithmetic.saturatingAdd(
                    save.homestead.resources[resource, default: 0],
                    accepted,
                )
            }
        }
    }
}
