import TrinketContent
import TrinketCore

/// Gameplay always accounts for economic effects, including an empty receipt set.
/// Snapshot inference is retained only for Debug fixtures that exercise older journals.
enum SaveMutationAccounting {
    case receipts([SaveEconomicReceipt])
    #if DEBUG
    case fixtureSnapshot
    #endif

    var receipts: [SaveEconomicReceipt]? {
        switch self {
        case let .receipts(receipts): receipts
        #if DEBUG
        case .fixtureSnapshot: nil
        #endif
        }
    }
}

/// A synchronous candidate and its effects have one lifetime and one commit.
final class SaveEconomicMutation {
    enum ValidationFailure: Error {
        case invalidReceipt
        case incompleteEffects
    }

    private let sourceSave: PlayerSave
    let sourceRevision: UInt64
    var save: PlayerSave
    private(set) var actions: [ResolvedSaveAction] = []
    #if DEBUG
    private var legacyReceipts: [SaveEconomicReceipt] = []
    #endif

    var receipts: [SaveEconomicReceipt] {
        #if DEBUG
        actions.map(\.receipt) + legacyReceipts
        #else
        actions.map(\.receipt)
        #endif
    }

    init(_ save: PlayerSave, sourceRevision: UInt64) {
        self.sourceRevision = sourceRevision
        sourceSave = save
        self.save = save
    }

    #if DEBUG
    /// Historical receipt fixtures cannot become a production authoring API.
    func record(_ receipt: SaveEconomicReceipt) {
        legacyReceipts.append(receipt)
    }
    #endif

    func resolve<Value, Failure: Error>(
        kind: SaveEconomicReceipt.Kind = .reward, claim: CloudEconomicAction.Claim? = nil,
        _ mutation: (inout PlayerSave) -> Result<Value, Failure>,
    ) -> Result<Value, Failure> {
        let before = save
        var candidate = save
        switch mutation(&candidate) {
        case let .failure(error): return .failure(error)
        case let .success(value):
            actions.append(ResolvedSaveAction(
                before: CloudSaveSnapshot(before), after: CloudSaveSnapshot(candidate), kind: kind, claim: claim,
            ))
            save = candidate
            return .success(value)
        }
    }

    func finalizedActions(at candidate: PlayerSave) throws -> [ResolvedSaveAction] {
        guard let last = actions.last else { return [] }
        do {
            var previous = CloudSaveSnapshot(sourceSave)
            for action in actions {
                try ResolvedSaveAction.requireNonEconomicChange(from: previous, to: action.before)
                previous = action.after
            }
            try ResolvedSaveAction.requireNonEconomicChange(from: last.after, to: CloudSaveSnapshot(save))
        } catch {
            throw ValidationFailure.incompleteEffects
        }
        // All child actions became durable together. Scalar conflict selection
        // uses that commit time, including children before the finalized last one.
        var committed = actions.dropLast().map { action in
            var after = action.after
            after.modifiedAt = candidate.modifiedAt
            return action.finalized(at: after)
        }
        committed.append(last.finalized(at: CloudSaveSnapshot(candidate)))
        return committed
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
        guard replayed.roster.gold == after.roster.gold,
              HomesteadResource.allCases.allSatisfy({
                  replayed.homestead.resources[$0, default: 0] == after.homestead.resources[$0, default: 0]
              }),
              (replayed.homestead.rewardRemainders ?? .zero) == (after.homestead.rewardRemainders ?? .zero)
        else {
            throw ValidationFailure.incompleteEffects
        }
        let ids = Set(replayed.roster.progressions.keys).union(after.roster.progressions.keys)
        guard ids.allSatisfy({
            (replayed.roster.progressions[$0] ?? .initial) == (after.roster.progressions[$0] ?? .initial)
        })
        else {
            throw ValidationFailure.incompleteEffects
        }
    }
}
