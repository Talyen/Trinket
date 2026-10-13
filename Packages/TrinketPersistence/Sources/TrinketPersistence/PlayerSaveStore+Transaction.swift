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
        let candidate = SaveEconomicMutation(currentSave)
        switch mutation(&candidate.save, candidate.record) {
        case let .failure(error): return .rejected(error)
        case let .success(value):
            do {
                try commit(candidate.save, accounting: .receipts(candidate.receipts))
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
        let candidate = SaveEconomicMutation(currentSave)
        mutation(&candidate.save, candidate.record)
        do {
            try commit(candidate.save, accounting: .receipts(candidate.receipts))
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
        let (candidate, result) = proposedSave(by: mutation)
        switch result {
        case let .failure(error):
            return .rejected(error)
        case let .success(value):
            do {
                try commit(candidate)
            } catch {
                notePersistenceFailure(error, logging: message)
                return .persistFailed(PlayerSavePersistenceError.mapped(error))
            }
            return .committed(value)
        }
    }
}
