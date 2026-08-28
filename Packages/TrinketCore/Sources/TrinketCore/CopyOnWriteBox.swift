/// Concurrency-Safety: `@unchecked Sendable` — box is mutated only while uniquely
public final class CopyOnWriteBox<Value>: @unchecked Sendable {
    public var value: Value
    public init(_ value: Value) {
        self.value = value
    }
}
