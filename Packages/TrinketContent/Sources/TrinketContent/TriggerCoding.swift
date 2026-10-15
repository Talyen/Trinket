import Foundation
import TrinketCore

struct TriggerCodingKey: CodingKey {
    let stringValue: String

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue _: Int) {
        nil
    }

    var intValue: Int? {
        nil
    }
}

/// One typed binding owns a field's flat save key, neutral default and comparison.
/// Gameplay reads and merges stay statically dispatched on the generated families.
struct TriggerField<Root: Sendable>: Sendable {
    let field: CombatTriggerField
    let differs: @Sendable (Root, Root) -> Bool
    let decode: @Sendable (KeyedDecodingContainer<TriggerCodingKey>, inout Root) throws -> Void
    let encode: @Sendable (Root, inout KeyedEncodingContainer<TriggerCodingKey>) throws -> Void

    init<Value: Codable & Equatable & Sendable>(
        _ keyPath: WritableKeyPath<Root, Value> & Sendable,
        _ field: CombatTriggerField,
        default defaultValue: Value,
    ) {
        self.field = field
        differs = { $0[keyPath: keyPath] != $1[keyPath: keyPath] }
        decode = { values, root in
            root[keyPath: keyPath] = try values.decodeIfPresent(Value.self, forKey: TriggerCodingKey(field.rawValue)) ?? defaultValue
        }
        encode = { root, container in
            let value = root[keyPath: keyPath]
            guard value != defaultValue else { return }
            try container.encode(value, forKey: TriggerCodingKey(field.rawValue))
        }
    }
}
