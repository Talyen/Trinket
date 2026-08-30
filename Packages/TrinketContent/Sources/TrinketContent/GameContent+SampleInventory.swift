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
                affixes: [definition.resolved(for: .astral)],
            )
        }

    static let sampleInventoryItems: [InventoryItem] = itemBaseTypes
        .filter { $0.slot != .trinket }
        .flatMap { base in
            Rarity.allCases
                .filter { $0 != .unique }
                .map { rarity in
                    var randomNumberGenerator = SeededRandomNumberGenerator(
                        seed: stableSeed(for: "\(base.id)-\(rarity.rawValue)"),
                    )
                    return ItemGenerator().generate(
                        id: "\(base.id)-\(rarity.rawValue)",
                        baseType: base,
                        rarity: rarity,
                        using: &randomNumberGenerator,
                    )
                }
        }

    static let itemTemplatesByID: [String: InventoryItem] = {
        var templates: [String: InventoryItem] = [:]
        for item in sampleInventoryItems {
            templates[item.id] = item
            templates[item.templateID] = item
        }
        for item in trinketItems {
            templates[item.id] = item
            templates[item.templateID] = item
        }
        return templates
    }()

    static func itemTemplate(matching id: String) -> InventoryItem? {
        itemTemplatesByID[id]
    }

    static func stableSeed(for text: String) -> UInt64 {
        text.utf8.reduce(14695981039346656037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1099511628211
        }
    }

    static func encounterSeed(_ worldSeed: UInt64, salt: String) -> UInt64 {
        worldSeed &+ stableSeed(for: salt)
    }
}
