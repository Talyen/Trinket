import Foundation
import TrinketContent
import TrinketCore

enum CloudSaveReconciler {
    struct Resolution {
        let head: CloudSaveHead
        let receipt: CloudSaveReceipt
        let backups: [CloudSaveBackup]
    }

    static func resolve(_ request: CloudSaveRequest, against server: CloudServerSave?) throws -> Resolution {
        _ = try request.revision.snapshot.restored()
        guard let server else {
            guard request.baseEpoch == nil else { throw CloudSaveError.missingHead }
            let head = CloudSaveHead(
                epoch: request.id,
                resetCount: request.action == .reset ? 1 : 0,
                authoritySequence: 0,
                revision: request.revision,
            )
            return resolution(head, request: request, outcome: .synchronized, backups: [], acceptedLocal: true)
        }
        guard server.head.formatVersion == 1 else { throw CloudSaveError.unsupportedSave }
        let existing = server.head
        var oldSave = try existing.revision.snapshot.restored()
        if !existing.productionClockEstablished {
            oldSave.homestead.lastProductionAt = min(oldSave.homestead.lastProductionAt, server.serverTime)
        }
        oldSave.homestead.settleProduction(at: server.serverTime, roster: oldSave.roster)
        let sameEpoch = request.baseEpoch == existing.epoch
            || (request.baseEpoch == nil && existing.resetCount == 0)
        var head = existing
        head.productionClockEstablished = true
        head.revision.id = request.id
        head.revision.clock.merge(request.revision.clock, uniquingKeysWith: max)

        if request.action == .reset, sameEpoch {
            // Reset keeps the request's game content (gold/inventory included:
            // reset means fresh game, not wiped wallet) but zeroes the
            // production clock so no pre-reset pending production survives.
            var resetSave = try request.revision.snapshot.restored()
            resetSave.homestead.lastProductionAt = server.serverTime
            resetSave.homestead.pendingProduction = [:]
            head.epoch = request.id
            head.resetCount += 1
            head.authoritySequence = 0
            head.revision.snapshot = CloudSaveSnapshot(resetSave)
            return resolution(head, request: request, outcome: .synchronized, backups: [
                backup(existing.revision, epoch: existing.epoch, requestID: request.id, suffix: "previous"),
            ], acceptedLocal: true)
        }

        guard sameEpoch, request.authoritySequence == existing.authoritySequence else {
            head.revision.snapshot = CloudSaveSnapshot(oldSave)
            return resolution(head, request: request, outcome: .progressChanged, backups: [
                backup(request.revision, epoch: request.baseEpoch, requestID: request.id, suffix: "incoming"),
            ])
        }

        switch request.action {
        case .upload:
            return try reconcileUpload(request, existing: existing, head: head, settledSave: oldSave)
        case .reset:
            throw CloudSaveError.conflict
        case .collect, .upgrade:
            guard request.baseRevisionID == existing.revision.id else {
                head.revision.snapshot = CloudSaveSnapshot(oldSave)
                return resolution(head, request: request, outcome: .progressChanged, backups: [])
            }
            return applyProduction(request, head: head, save: oldSave, at: server.serverTime)
        }
    }

    private static func reconcileUpload(
        _ request: CloudSaveRequest,
        existing: CloudSaveHead,
        head: CloudSaveHead,
        settledSave: PlayerSave,
    ) throws -> Resolution {
        var head = head
        let incoming = request.revision
        let current = existing.revision
        let useIncoming: Bool = if !incoming.snapshot.hasProgress, request.baseEpoch == nil {
            false
        } else if current.includes(incoming.clock) {
            false
        } else if incoming.includes(current.clock) {
            true
        } else {
            preferred(incoming, over: current)
        }
        let concurrent = !current.includes(incoming.clock) && !incoming.includes(current.clock)
        var backups: [CloudSaveBackup] = []
        if concurrent || (!useIncoming && incoming.snapshot != current.snapshot) {
            backups.append(backup(
                useIncoming ? current : incoming,
                epoch: useIncoming ? existing.epoch : request.baseEpoch,
                requestID: request.id,
                suffix: useIncoming ? "previous" : "incoming",
            ))
        }
        let incomingSave = try incoming.snapshot.restored()
        let shouldMerge = concurrent || (request.baseEpoch == nil && incoming.snapshot.hasProgress && current.snapshot.hasProgress)
        let mutations = request.mutations ?? []
        var selected: PlayerSave
        if !mutations.isEmpty {
            selected = try replay(mutations, onto: settledSave)
            if let last = try mutations.last?.after.restored(), last.hasDomainDifference(from: incomingSave) {
                selected = CloudSaveMerge.merge(
                    incoming: incomingSave, existing: selected, base: last, preferIncoming: true,
                )
            }
        } else if shouldMerge {
            selected = try CloudSaveMerge.merge(
                incoming: incomingSave, existing: settledSave,
                base: request.baseSnapshot?.restored(), preferIncoming: useIncoming,
            )
        } else {
            selected = useIncoming ? incomingSave : settledSave
        }
        // Server production cursor is authoritative: the winner adopts the
        // settled clock/pending so a branch predating a committed claim or
        // upgrade can never undo that operation via Campaign rank.
        selected.homestead.lastProductionAt = max(selected.homestead.lastProductionAt, settledSave.homestead.lastProductionAt)
        if mutations.isEmpty, !shouldMerge, request.baseSnapshot?.homestead == incoming.snapshot.homestead {
            selected.homestead.pendingProduction = settledSave.homestead.pendingProduction
        }
        head.revision.snapshot = CloudSaveSnapshot(selected)
        return resolution(
            head, request: request, outcome: .synchronized, backups: backups,
            acceptedLocal: (useIncoming && !shouldMerge) || selected == incomingSave,
        )
    }

    private static func replay(_ mutations: [CloudSaveMutation], onto initial: PlayerSave) throws -> PlayerSave {
        var projected = initial
        var seen: Set<String> = []
        for mutation in mutations where mutation.changedSliceMask != 0 && seen.insert(mutation.id).inserted {
            let before = try mutation.before.restored()
            let after = try mutation.after.restored()
            projected = CloudSaveMerge.merge(incoming: after, existing: projected, base: before, preferIncoming: true)
        }
        return projected
    }

    private static func preferred(_ lhs: CloudSaveRevision, over rhs: CloudSaveRevision) -> Bool {
        if lhs.snapshot.hasProgress != rhs.snapshot.hasProgress {
            return lhs.snapshot.hasProgress
        }
        if lhs.snapshot.campaignRank != rhs.snapshot.campaignRank {
            return lhs.snapshot.campaignRank > rhs.snapshot.campaignRank
        }
        if lhs.snapshot.modifiedAt != rhs.snapshot.modifiedAt {
            return lhs.snapshot.modifiedAt > rhs.snapshot.modifiedAt
        }
        return lhs.id > rhs.id
    }

    private static func applyProduction(
        _ request: CloudSaveRequest,
        head: CloudSaveHead,
        save: PlayerSave,
        at date: Date,
    ) -> Resolution {
        var head = head
        var save = save
        let outcome: CloudSaveReceipt.Outcome
        switch request.action {
        case .collect:
            let collected = save.homestead.collectProduction(at: date, roster: &save.roster)
            outcome = .collected(Dictionary(uniqueKeysWithValues: collected.map { ($0.resource, $0.quantity) }))
            if !collected.isEmpty {
                head.authoritySequence += 1
            }
        case let .upgrade(nodeID, tier):
            guard let definition = GameContent.homesteadNode(matching: nodeID)
            else { return resolution(head, request: request, outcome: .notAvailable, backups: []) }
            switch HomesteadBuildMutation.apply(definition, targetTier: tier, at: date, to: &save) {
            case .success: break
            case .failure(.insufficientResources):
                return resolution(head, request: request, outcome: .insufficientResources, backups: [])
            case .failure(.notAvailable):
                return resolution(head, request: request, outcome: .notAvailable, backups: [])
            }
            outcome = .upgraded
            head.authoritySequence += 1
        case .upload, .reset:
            // Unreachable: uploads resolve in reconcileUpload, resets throw
            // conflict above. Defensive default keeps the switch exhaustive
            // if a new action is added.
            outcome = .notAvailable
        }
        head.revision.snapshot = CloudSaveSnapshot(save)
        return resolution(head, request: request, outcome: outcome, backups: [])
    }

    private static func backup(
        _ revision: CloudSaveRevision,
        epoch: String?,
        requestID: String,
        suffix: String,
    ) -> CloudSaveBackup {
        CloudSaveBackup(id: "\(requestID)-\(suffix)", epoch: epoch, snapshot: revision.snapshot)
    }

    private static func resolution(
        _ head: CloudSaveHead,
        request: CloudSaveRequest,
        outcome: CloudSaveReceipt.Outcome,
        backups: [CloudSaveBackup],
        acceptedLocal: Bool = false,
    ) -> Resolution {
        Resolution(head: head, receipt: CloudSaveReceipt(
            requestID: request.id, epoch: head.epoch, authoritySequence: head.authoritySequence, outcome: outcome,
            acceptedLocalSnapshot: acceptedLocal,
        ), backups: backups)
    }
}
