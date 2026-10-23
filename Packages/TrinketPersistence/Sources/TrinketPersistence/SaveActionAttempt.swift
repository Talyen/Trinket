/// A product result and the storage failure from the command that produced it.
/// Retry scheduling consumes this value; diagnostics never supply control flow.
public struct SaveActionAttempt<Value> {
    public let value: Value
    public let failure: PlayerSavePersistenceError?

    public init(_ value: Value, failure: PlayerSavePersistenceError? = nil) {
        self.value = value
        self.failure = failure
    }

    public func map<Output>(_ transform: (Value) -> Output) -> SaveActionAttempt<Output> {
        SaveActionAttempt<Output>(transform(value), failure: failure)
    }

    public static func catching(failureValue: Value, _ operation: () throws -> Value) -> Self {
        do {
            return try Self(operation())
        } catch {
            return Self(failureValue, failure: PlayerSavePersistenceError.mapped(error))
        }
    }
}

extension SaveActionAttempt: Equatable where Value: Equatable {}
extension SaveActionAttempt: Sendable where Value: Sendable {}

public extension SaveTransactionResult {
    var persistenceError: PlayerSavePersistenceError? {
        if case let .persistFailed(error) = self {
            error
        } else {
            nil
        }
    }
}
