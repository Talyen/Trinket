#if DEBUG
@MainActor
extension PlayerSaveStore {
    /// Unrestricted setup and legacy snapshot-replay coverage are intentionally
    /// separate from gameplay transactions and unavailable in Release builds.
    func performFixtureMutation(
        _ mutation: (inout PlayerSave) -> Void,
    ) throws {
        var candidate = currentSave
        mutation(&candidate)
        try commit(candidate, accounting: .fixtureSnapshot)
    }

    @discardableResult
    func persistFixtureBatch(logging message: String, _ mutation: (inout PlayerSave) -> Void) -> Bool {
        do {
            try performFixtureMutation(mutation)
            return true
        } catch {
            notePersistenceFailure(error, logging: message)
            return false
        }
    }
}
#endif
