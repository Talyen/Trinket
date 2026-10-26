import Foundation
import TrinketContent
import TrinketCore

/// One admitted action owns both its structural changes and economic effects.
/// Amounts are derived from the recorded values, never authored a second time.
struct ResolvedSaveAction: Equatable, Sendable {
    let before: CloudSaveSnapshot
    let after: CloudSaveSnapshot
    let kind: SaveEconomicReceipt.Kind
    let claim: CloudEconomicAction.Claim?

    var receipt: SaveEconomicReceipt {
        .resolved(from: before, to: after, kind: kind, claim: claim)
    }

    func finalized(at snapshot: CloudSaveSnapshot) -> Self {
        Self(before: before, after: snapshot, kind: kind, claim: claim)
    }

    static func requireNonEconomicChange(from before: CloudSaveSnapshot, to after: CloudSaveSnapshot) throws {
        guard SaveEconomicReceipt.resolved(from: before, to: after, kind: .reward, claim: nil).effects == .committed()
        else { throw CloudSaveError.unsupportedSave }
    }

    static func records(
        _ actions: [Self], following snapshot: CloudSaveSnapshot, positions: inout [HomesteadResource: UInt64],
    ) throws -> [Record] {
        var previous = snapshot
        return try actions.enumerated().map { index, action in
            let positioned = try action.receipt.positioningCollections(&positions)
            try positioned.validate()
            let resolved = Self(before: action.before, after: action.after, kind: positioned.kind, claim: action.claim)
            defer { previous = action.after }
            return Record(resolved, following: previous, collectionPositions: positions, usesFinalSnapshot: index == actions.count - 1)
        }
    }

    /// Deltas share the enclosing journal's checkpoint. Gaps contain unrelated
    /// non-economic edits; intermediate actions retain their own result. The last
    /// action reuses the enclosing mutation's final snapshot rather than encoding
    /// its Inventory/map payload a second time.
    struct Record: Codable, Equatable, Sendable {
        var formatVersion = 1
        let gap: CloudSaveSnapshotDelta
        let change: CloudSaveSnapshotDelta?
        let kind: SaveEconomicReceipt.Kind
        let claim: CloudEconomicAction.Claim?
        let collectionPositions: [HomesteadResource: UInt64]

        init(
            _ action: ResolvedSaveAction, following previous: CloudSaveSnapshot,
            collectionPositions: [HomesteadResource: UInt64] = [:], usesFinalSnapshot: Bool = false,
        ) {
            gap = CloudSaveSnapshotDelta(from: previous, to: action.before)
            change = usesFinalSnapshot ? nil : CloudSaveSnapshotDelta(from: action.before, to: action.after)
            kind = action.kind
            claim = action.claim
            self.collectionPositions = collectionPositions
        }

        func resolved(following previous: CloudSaveSnapshot, finalSnapshot: CloudSaveSnapshot? = nil) throws -> ResolvedSaveAction {
            guard formatVersion == 1 else { throw CloudSaveError.unsupportedSave }
            let before = gap.applying(to: previous)
            guard let after = change?.applying(to: before) ?? finalSnapshot else { throw CloudSaveError.unsupportedSave }
            guard [before, after].allSatisfy({
                PlayerSave.supportedSchemaVersions.contains($0.schemaVersion)
                    && $0.modifiedAt.timeIntervalSince1970.isFinite && !$0.labyrinth.isMapPayloadUnreadable
            }) else { throw CloudSaveError.unsupportedSave }
            let action = ResolvedSaveAction(before: before, after: after, kind: kind, claim: claim)
            try action.receipt.validate()
            return action
        }
    }
}

extension SaveEconomicReceipt {
    /// Compute from stored values before catalog repair: replay must retain the
    /// admitted amounts even when the current content differs from the writer's.
    static func resolved(
        from before: CloudSaveSnapshot, to after: CloudSaveSnapshot,
        kind: Kind, claim: CloudEconomicAction.Claim?,
    ) -> Self {
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
            let delta = (after.roster.progressions[id] ?? .initial)
                .experienceGained(since: before.roster.progressions[id] ?? .initial) ?? -1
            if delta != 0 {
                experience[id] = delta
            }
        }
        let first = before.homestead.rewardRemainders ?? .zero
        let last = after.homestead.rewardRemainders ?? .zero
        return Self(kind: kind, effects: .committed(
            claim: claim, gold: SaturatedArithmetic.saturatingSub(after.roster.gold, before.roster.gold), materials: materials,
            experience: experience,
            goldRemainder: SaturatedArithmetic.saturatingSub(last.gold, first.gold),
            gemsRemainder: SaturatedArithmetic.saturatingSub(last.gems, first.gems),
        ))
    }
}
