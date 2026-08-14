import Foundation
import TrinketCore

public extension GameContent {
    static let trinketItems: [InventoryItem] = itemBaseTypes
        .filter { $0.slot == .trinket }
        .compactMap { base in
            guard let definition = itemAffixDefinition(matching: base.id) else {
                return nil
            }
            return InventoryItem(
                id: base.id,
                templateID: base.id,
                baseType: base,
                rarity: .astral,
                displayName: base.name,
                affixes: [definition.resolved(for: .astral)]
            )
        }

    static let sampleInventoryItems: [InventoryItem] = itemBaseTypes
        .filter { $0.slot != .trinket }
        .flatMap { base in
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
        (sampleInventoryItems + trinketItems).first { $0.id == id || $0.templateID == id }
    }

    static func stableSeed(for text: String) -> UInt64 {
        text.utf8.reduce(14695981039346656037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1099511628211
        }
    }
}
