#if DEBUG
@MainActor
extension PlayerSaveStore {
    /// Explicit historical-receipt fixtures are unavailable to Release gameplay.
    func persistTransaction<Value, Failure: Error>(
        logging message: String,
        _ mutation: (inout PlayerSave, (SaveEconomicReceipt) -> Void) -> Result<Value, Failure>,
    ) -> SaveTransactionResult<Value, Failure> {
        let candidate = makeMutation()
        return finishTransaction(candidate, logging: message, result: mutation(&candidate.save, candidate.record))
    }

    @discardableResult
    func persistBatch(logging message: String, _ mutation: (inout PlayerSave, (SaveEconomicReceipt) -> Void) -> Void) -> Bool {
        let candidate = makeMutation()
        mutation(&candidate.save, candidate.record)
        let result: SaveTransactionResult<Void, Never> = finishTransaction(candidate, logging: message, result: .success(()))
        if case .committed = result {
            return true
        }
        return false
    }

    /// Unrestricted setup and legacy snapshot-replay coverage are intentionally
    /// separate from gameplay transactions and unavailable in Release builds.
    func performFixtureMutation(
        _ mutation: (inout PlayerSave) -> Void,
    ) throws {
        let candidate = makeMutation()
        mutation(&candidate.save)
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
