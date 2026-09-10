public enum SaveTransactionResult<Value, Failure: Error> {
    case committed(Value)
    case rejected(Failure)
    case persistFailed
}

@MainActor
public extension PlayerSaveStore {
    func persistTransaction<Value, Failure: Error>(
        logging message: String,
        _ mutation: (inout PlayerSave) -> Result<Value, Failure>,
    ) -> SaveTransactionResult<Value, Failure> {
        var candidate = currentSave
        switch mutation(&candidate) {
        case let .failure(error):
            return .rejected(error)
        case let .success(value):
            guard persistBatch(logging: message, { $0 = candidate }) else { return .persistFailed }
            return .committed(value)
        }
    }
}
