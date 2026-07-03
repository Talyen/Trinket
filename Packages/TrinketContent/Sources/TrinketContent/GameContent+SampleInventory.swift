import Foundation
import TrinketCore

public extension GameContent {
    static let sampleInventoryItems: [InventoryItem] = itemBaseTypes.flatMap { base in
        Rarity.allCases.map { rarity in
            var randomNumberGenerator = SeededRandomNumberGenerator(
                seed: stableSeed(for: "\(base.id)-\(rarity.rawValue)")
            )
            return ItemGenerator().generate(
                id: "\(base.id)-\(rarity.rawValue)",
                baseType: base,
                rarity: rarity,
                using: &randomNumberGenerator
            )
        }
    }

    static func itemTemplate(matching id: String) -> InventoryItem? {
        sampleInventoryItems.first { $0.id == id || $0.templateID == id }
    }

    static func stableSeed(for text: String) -> UInt64 {
        text.utf8.reduce(14695981039346656037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1099511628211
        }
    }
}
