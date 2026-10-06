public enum SaveTransactionResult<Value, Failure: Error> {
    case committed(Value)
    case rejected(Failure)
    case persistFailed
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
                try commit(candidate.save, receipts: candidate.receipts)
                return .committed(value)
            } catch {
                notePersistenceFailure(error, logging: message)
                return .persistFailed
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
            try commit(candidate.save, receipts: candidate.receipts)
            return true
        } catch {
            notePersistenceFailure(error, logging: message)
            return false
        }
    }

    /// Transactional commit spelling. Transactions are always immediate;
    /// deferred writes use `performBatchMutation(persistImmediately: false)`.
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
                return .persistFailed
            }
            return .committed(value)
        }
    }
}
