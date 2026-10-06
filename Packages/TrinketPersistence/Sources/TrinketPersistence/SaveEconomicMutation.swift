import TrinketContent
import TrinketCore

/// A synchronous candidate and its effects have one lifetime and one commit.
final class SaveEconomicMutation {
    enum ValidationFailure: Error {
        case invalidReceipt
        case incompleteEffects
    }

    var save: PlayerSave
    private(set) var receipts: [SaveEconomicReceipt] = []

    init(_ save: PlayerSave) {
        self.save = save
    }

    func record(_ receipt: SaveEconomicReceipt) {
        receipts.append(receipt)
    }

    static func validate(from before: PlayerSave, to after: PlayerSave, receipts: [SaveEconomicReceipt]) throws {
        var replayed = before
        var positions: [HomesteadResource: UInt64] = [:]
        for receipt in receipts {
            do {
                try receipt.positioningCollections(&positions).validate()
            } catch {
                throw ValidationFailure.invalidReceipt
            }
            receipt.effects.applyEffects(to: &replayed)
        }
        let ids = Set(replayed.roster.progressions.keys).union(after.roster.progressions.keys)
        guard replayed.roster.gold == after.roster.gold,
              HomesteadResource.allCases.allSatisfy({
                  replayed.homestead.resources[$0, default: 0] == after.homestead.resources[$0, default: 0]
              }),
              (replayed.homestead.rewardRemainders ?? .zero) == (after.homestead.rewardRemainders ?? .zero),
              ids.allSatisfy({
                  (replayed.roster.progressions[$0] ?? .initial).totalEarnedExperience
                      == (after.roster.progressions[$0] ?? .initial).totalEarnedExperience
              })
        else {
            throw ValidationFailure.incompleteEffects
        }
    }
}

extension SaveEconomicReceipt {
    /// Capture effects at the owning single-action boundary, never across a
    /// batch of claims whose separate payouts need independent replay identities.
    static func reward(from before: PlayerSave, to after: PlayerSave, claim: CloudEconomicAction.Claim? = nil) -> Self {
        var materials: [HomesteadResource: Int] = [:]
        for resource in HomesteadResource.allCases where resource != .gold {
            let delta = SaturatedArithmetic.saturatingSub(
                after.homestead.resources[resource, default: 0], before.homestead.resources[resource, default: 0],
            )
            if delta != 0 {
                materials[resource] = delta
            }
        }
        var experience: [String: Int] = [:]
        for id in Set(before.roster.progressions.keys).union(after.roster.progressions.keys) {
            let delta = SaturatedArithmetic.saturatingSub(
                (after.roster.progressions[id] ?? .initial).totalEarnedExperience,
                (before.roster.progressions[id] ?? .initial).totalEarnedExperience,
            )
            if delta != 0 {
                experience[id] = delta
            }
        }
        let first = before.homestead.rewardRemainders ?? .zero
        let last = after.homestead.rewardRemainders ?? .zero
        return Self(kind: .reward, effects: .committed(
            claim: claim, gold: after.roster.gold - before.roster.gold, materials: materials, experience: experience,
            goldRemainder: last.gold - first.gold, gemsRemainder: last.gems - first.gems,
        ))
    }
}
