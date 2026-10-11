/// CPU-bound cloud planning accepts immutable values only. SwiftData, observed
/// publication and presentation preparation remain on the store's main actor.
enum CloudSavePlanner {
    @concurrent
    static func resolve(
        _ request: CloudSaveRequest, against server: CloudServerSave?,
    ) async throws -> CloudSaveReconciler.Resolution {
        try Task.checkCancellation()
        let resolution = try CloudSaveReconciler.resolve(request, against: server)
        try Task.checkCancellation()
        return resolution
    }

    @concurrent
    static func bind(
        _ accountID: String?, state: CloudDeviceState, local: CloudSaveSnapshot,
    ) async throws -> CloudSaveTransition? {
        try Task.checkCancellation()
        let transition = try CloudSaveTransitions.bind(accountID, state: state, local: local)
        try Task.checkCancellation()
        return transition
    }

    @concurrent
    static func importRemote(
        _ head: CloudSaveHead, state: CloudDeviceState, local: CloudSaveSnapshot,
    ) async throws -> CloudSaveTransition? {
        try Task.checkCancellation()
        let transition = try CloudSaveTransitions.importRemote(head, state: state, local: local)
        try Task.checkCancellation()
        return transition
    }

    @concurrent
    static func acknowledge(
        _ request: CloudSaveRequest, receipt: CloudSaveReceipt, head: CloudSaveHead,
        accountID: String, state: CloudDeviceState, local: CloudSaveSnapshot,
    ) async throws -> CloudSaveTransitions.Acknowledgement? {
        try Task.checkCancellation()
        let acknowledgement = try CloudSaveTransitions.acknowledge(
            request, receipt: receipt, head: head, accountID: accountID, state: state, local: local,
        )
        try Task.checkCancellation()
        return acknowledgement
    }
}
