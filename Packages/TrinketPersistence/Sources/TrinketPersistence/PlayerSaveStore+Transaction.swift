public enum SaveTransactionResult<Value, Failure: Error> {
    case committed(Value)
    case rejected(Failure)
    case persistFailed(PlayerSavePersistenceError)
}

@MainActor
extension PlayerSaveStore {
    /// Commits a candidate only after the domain operation accepts it.
    func persistTransaction<Value, Failure: Error>(
        logging message: String,
        _ mutation: (inout PlayerSave) -> Result<Value, Failure>,
    ) -> SaveTransactionResult<Value, Failure> {
        let candidate = makeMutation()
        return finishTransaction(candidate, logging: message, result: mutation(&candidate.save))
    }

    func persistAction<Value, Failure: Error>(
        kind: SaveEconomicReceipt.Kind = .reward, claim: CloudEconomicAction.Claim? = nil,
        logging message: String,
        _ mutation: (inout PlayerSave) -> Result<Value, Failure>,
    ) -> SaveTransactionResult<Value, Failure> {
        let candidate = makeMutation()
        return finishTransaction(candidate, logging: message, result: candidate.resolve(kind: kind, claim: claim, mutation))
    }

    func finishTransaction<Value, Failure: Error>(
        _ candidate: SaveEconomicMutation, logging message: String, result: Result<Value, Failure>,
    ) -> SaveTransactionResult<Value, Failure> {
        switch result {
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
}
