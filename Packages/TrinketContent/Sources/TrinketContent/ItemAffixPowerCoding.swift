import Foundation

public enum ItemAffixPowerCoding {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    public static func encode(_ powers: [ItemAffixPower]) throws -> Data {
        try encoder.encode(powers)
    }

    public static func decode(_ data: Data) throws -> [ItemAffixPower] {
        try decoder.decode([ItemAffixPower].self, from: data)
    }
}
