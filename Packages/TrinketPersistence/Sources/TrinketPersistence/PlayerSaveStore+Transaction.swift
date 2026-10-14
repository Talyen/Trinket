public enum SaveTransactionResult<Value, Failure: Error> {
    case committed(Value)
    case rejected(Failure)
    case persistFailed(PlayerSavePersistenceError)
}

@MainActor
extension PlayerSaveStore {
    /// Domain owners supply receipts in the same synchronous candidate mutation.
    /// A rejection or refused durable write discards both the save and receipts.
    func persistTransaction<Value, Failure: Error>(
        logging message: String,
        _ mutation: (inout PlayerSave, (SaveEconomicReceipt) -> Void) -> Result<Value, Failure>,
    ) -> SaveTransactionResult<Value, Failure> {
        let candidate = makeMutation()
        switch mutation(&candidate.save, candidate.record) {
        case let .failure(error): return .rejected(error)
        case let .success(value):
            do {
                try commit(candidate)
                return .committed(value)
            } catch {
                notePersistenceFailure(error, logging: message)
                return .persistFailed(PlayerSavePersistenceError.mapped(error))
            }
        }
    }

    @discardableResult
    func persistBatch(
        logging message: String,
        _ mutation: (inout PlayerSave, (SaveEconomicReceipt) -> Void) -> Void,
    ) -> Bool {
        let candidate = makeMutation()
        mutation(&candidate.save, candidate.record)
        do {
            try commit(candidate)
            return true
        } catch {
            notePersistenceFailure(error, logging: message)
            return false
        }
    }

    /// Commits a candidate only after the domain operation accepts it.
    func persistTransaction<Value, Failure: Error>(
        logging message: String,
        _ mutation: (inout PlayerSave) -> Result<Value, Failure>,
    ) -> SaveTransactionResult<Value, Failure> {
        persistTransaction(logging: message) { save, _ in mutation(&save) }
    }
}
