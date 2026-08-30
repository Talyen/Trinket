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
