/// Generic copy-on-write box for large value types that are copied through
/// recursive pipelines. Replaces two ad-hoc `final class Storage` implementations
/// (`CombatTraitTriggers.Storage` + `CombatantRuntime.TalentBox`) with one.
///
/// Concurrency-Safety: `@unchecked Sendable` — box is mutated only while uniquely
/// referenced via `isKnownUniquelyReferenced`; copies clone `Value`.
public final class CopyOnWriteBox<Value>: @unchecked Sendable {
    public var value: Value
    public init(_ value: Value) {
        self.value = value
    }
}
