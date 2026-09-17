public enum SaveTransactionResult<Value, Failure: Error> {
    case committed(Value)
    case rejected(Failure)
    case persistFailed
}

@MainActor
public extension PlayerSaveStore {
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
