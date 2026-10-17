import Foundation
import TrinketCore

/// A typed binding owns the field's saved identity, default and stacking rule.
struct TriggerField<Root: Sendable>: Sendable {
    let field: CombatTriggerField
    let merge: @Sendable (Root, inout Root) -> Void
    let differs: @Sendable (Root, Root) -> Bool
    let decode: @Sendable (KeyedDecodingContainer<CombatTriggerField>, inout Root) throws -> Void
    let encode: @Sendable (Root, inout KeyedEncodingContainer<CombatTriggerField>) throws -> Void

    init<Value: Codable & Equatable & Sendable>(
        _ keyPath: WritableKeyPath<Root, Value> & Sendable,
        _ field: CombatTriggerField,
        default defaultValue: Value,
        merging rule: TriggerMerge<Value>,
    ) {
        self.field = field
        merge = { incoming, root in
            root[keyPath: keyPath] = rule.combine(root[keyPath: keyPath], incoming[keyPath: keyPath])
        }
        differs = { $0[keyPath: keyPath] != $1[keyPath: keyPath] }
        decode = { values, root in
            root[keyPath: keyPath] = try values.decodeIfPresent(Value.self, forKey: field) ?? defaultValue
        }
        encode = { root, container in
            let value = root[keyPath: keyPath]
            guard value != defaultValue else { return }
            try container.encode(value, forKey: field)
        }
    }
}

/// Only type-compatible policies are available to the generated registry.
struct TriggerMerge<Value>: Sendable {
    let combine: @Sendable (Value, Value) -> Value
}

extension TriggerMerge where Value == Int {
    static var add: Self {
        Self { SaturatedArithmetic.saturatingAdd($0, $1) }
    }
}

extension TriggerMerge where Value == Double {
    static var add: Self {
        Self { $0 + $1 }
    }
}

extension TriggerMerge where Value: Numeric & Sendable {
    static var mul: Self {
        Self { $0 * $1 }
    }

    static var addExcess: Self {
        Self { $0 + ($1 - 1) }
    }
}

extension TriggerMerge where Value: Comparable & Sendable {
    static var max: Self {
        Self { Swift.max($0, $1) }
    }
}

extension TriggerMerge where Value == Bool {
    static var or: Self {
        Self { $0 || $1 }
    }
}

extension TriggerMerge where Value == Keyword? {
    static var coalesce: Self {
        Self { $1 ?? $0 }
    }
}

extension TriggerMerge where Value == [Int] {
    static var union: Self {
        Self { current, incoming in
            guard !incoming.isEmpty else { return current }
            return current.isEmpty ? incoming.sorted() : Array(Set(current).union(incoming)).sorted()
        }
    }
}
