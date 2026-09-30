/// A proposed local transition, including the source that must still be current
/// after asynchronous presentation preparation. Computing a plan never writes a save.
struct CloudSaveTransition {
    let sourceState: CloudDeviceState
    let sourceSnapshot: CloudSaveSnapshot
    let state: CloudDeviceState
    var replacement: PlayerSave?
    var invalidatesSession = true

    func matches(state: CloudDeviceState, local: CloudSaveSnapshot) -> Bool {
        state == sourceState && local == sourceSnapshot
    }
}

/// Device-side rules only. The sync coordinator owns transport, cancellation,
/// presentation preparation and durable commits; server merge rules stay in
/// `CloudSaveReconciler`.
enum CloudSaveTransitions {
    struct Acknowledgement {
        let transition: CloudSaveTransition
        let isCurrent: Bool
        let operationReceipt: CloudSaveReceipt?
    }

    static func enqueue(
        _ action: CloudSaveRequest.Action,
        state original: CloudDeviceState,
        local: CloudSaveSnapshot,
        id: String,
    ) -> (CloudDeviceState, CloudSaveRequest) {
        var state = original
        let base = state.account.base
        state.counter = max(state.counter, base?.revision.clock[state.deviceID] ?? 0) + 1
        var clock = base?.revision.clock ?? [:]
        clock[state.deviceID] = state.counter
        let request = CloudSaveRequest(
            id: id,
            action: action,
            baseEpoch: base?.epoch,
            baseRevisionID: base?.revision.id,
            authoritySequence: base?.authoritySequence ?? 0,
            revision: CloudSaveRevision(id: id, clock: clock, snapshot: local),
            baseSnapshot: base?.revision.snapshot,
            mutations: action == .upload ? state.account.journal : nil,
        )
        state.account.pending = request
        return (state, request)
    }

    static func bind(
        _ accountID: String?,
        state original: CloudDeviceState,
        local: CloudSaveSnapshot,
    ) throws -> CloudSaveTransition? {
        guard original.activeAccountID != accountID else { return nil }
        var state = original
        if let previous = state.activeAccountID {
            state.archiving(CloudAccountArchive(snapshot: local, state: state.account), for: previous)
        }
        let replacement: PlayerSave?
        if let accountID {
            if !state.hasLinkedAccount {
                state.guestBackup = local
                state.account = CloudAccountState()
                replacement = nil
            } else if let archive = state.archives.removeValue(forKey: accountID) {
                if state.activeAccountID == nil {
                    state.guestBackup = local
                }
                state.account = archive.state
                replacement = try archive.snapshot.restored()
            } else {
                if state.activeAccountID == nil {
                    state.guestBackup = local
                }
                state.account = CloudAccountState()
                replacement = .fresh
            }
            state.hasLinkedAccount = true
        } else {
            state.account = CloudAccountState()
            replacement = nil
        }
        state.activeAccountID = accountID
        return CloudSaveTransition(sourceState: original, sourceSnapshot: local, state: state, replacement: replacement)
    }

    static func importRemote(
        _ head: CloudSaveHead,
        state original: CloudDeviceState,
        local: CloudSaveSnapshot,
    ) throws -> CloudSaveTransition? {
        guard original.account.base?.revision.snapshot == local,
              !original.account.resetRequested else { return nil }
        var state = original
        state.account.base = head
        let replacement = original.account.base == head ? nil : try head.revision.snapshot.restored()
        return CloudSaveTransition(sourceState: original, sourceSnapshot: local, state: state, replacement: replacement)
    }

    static func acknowledge(
        _ request: CloudSaveRequest,
        receipt: CloudSaveReceipt,
        head: CloudSaveHead,
        accountID: String,
        state original: CloudDeviceState,
        local: CloudSaveSnapshot,
    ) throws -> Acknowledgement? {
        guard original.activeAccountID == accountID else { throw CloudSaveError.accountChanged }
        guard original.account.pending?.id == request.id else { return nil }
        var state = original
        state.account.pending = nil
        if receipt.outcome == .progressChanged, request.action == .upload,
           receipt.epoch == head.epoch, request.baseEpoch == head.epoch {
            state.account.base = head
            return Acknowledgement(
                transition: CloudSaveTransition(sourceState: original, sourceSnapshot: local, state: state),
                isCurrent: false,
                operationReceipt: nil,
            )
        }
        if let applied = request.mutations, !applied.isEmpty {
            let ids = Set(applied.map(\.id))
            state.account.journal?.removeAll { ids.contains($0.id) }
        }
        let sourceUnchanged = local == request.revision.snapshot
        var transition = CloudSaveTransition(sourceState: original, sourceSnapshot: local, state: state)
        if sourceUnchanged {
            state.account.base = head
            state.account.resetRequested = false
            let isOwnChange: Bool = switch receipt.outcome {
            case .collected, .upgraded:
                head.revision.id == request.id
            default:
                receipt.acceptedLocalSnapshot && head.revision.id == request.id
            }
            transition = try CloudSaveTransition(
                sourceState: original, sourceSnapshot: local, state: state,
                replacement: head.revision.snapshot.restored(), invalidatesSession: !isOwnChange,
            )
        } else {
            // Only our own accepted revision is an ancestor of newer local play.
            // An unseen remote merge must remain outside that play's shared base.
            if receipt.outcome == .synchronized, receipt.epoch == head.epoch,
               head.revision.id == request.id {
                state.account.base = head
                if request.action == .reset {
                    state.account.resetRequested = false
                }
            }
            transition = CloudSaveTransition(sourceState: original, sourceSnapshot: local, state: state)
        }
        let isProduction = request.action != .upload && request.action != .reset
        return Acknowledgement(
            transition: transition, isCurrent: sourceUnchanged, operationReceipt: isProduction ? receipt : nil,
        )
    }
}
