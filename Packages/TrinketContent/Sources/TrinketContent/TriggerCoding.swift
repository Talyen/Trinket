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

struct DefaultingTriggerDecoder {
    let values: KeyedDecodingContainer<TriggerCodingKey>

    init(_ decoder: Decoder) throws {
        values = try decoder.container(keyedBy: TriggerCodingKey.self)
    }

    init(values: KeyedDecodingContainer<TriggerCodingKey>) {
        self.values = values
    }

    func decode<Value: Decodable>(
        _ type: Value.Type,
        _ key: String,
        default defaultValue: Value,
    ) throws -> Value {
        try values.decodeIfPresent(type, forKey: TriggerCodingKey(key)) ?? defaultValue
    }
}

extension KeyedEncodingContainer where K == TriggerCodingKey {
    mutating func encodeNonDefault<Value: Encodable & Equatable>(
        _ value: Value,
        _ key: String,
        default defaultValue: Value,
    ) throws {
        guard value != defaultValue else { return }
        try encode(value, forKey: TriggerCodingKey(key))
    }
}

/// One typed binding owns a field's flat save key, neutral default and comparison.
/// Gameplay reads and merges stay statically dispatched on the generated families.
struct TriggerField<Root: Sendable>: Sendable {
    let field: CombatTriggerField
    let differs: @Sendable (Root, Root) -> Bool
    let decode: @Sendable (DefaultingTriggerDecoder, inout Root) throws -> Void
    let encode: @Sendable (Root, inout KeyedEncodingContainer<TriggerCodingKey>) throws -> Void

    init<Value: Codable & Equatable & Sendable>(
        _ keyPath: WritableKeyPath<Root, Value> & Sendable,
        _ field: CombatTriggerField,
        default defaultValue: Value,
    ) {
        self.field = field
        differs = { $0[keyPath: keyPath] != $1[keyPath: keyPath] }
        decode = { values, root in
            root[keyPath: keyPath] = try values.decode(Value.self, field.rawValue, default: defaultValue)
        }
        encode = { root, container in
            try container.encodeNonDefault(root[keyPath: keyPath], field.rawValue, default: defaultValue)
        }
    }
}
