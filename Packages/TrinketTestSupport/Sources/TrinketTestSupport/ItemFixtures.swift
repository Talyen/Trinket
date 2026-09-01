import TrinketContent
import TrinketCore

public enum ItemFixtures {
    public enum FixtureError: Error {
        case missingItemBaseType(String)
    }

    public static func baseType(_ id: String) throws -> ItemBaseType {
        guard let base = GameContent.itemBaseType(matching: id) else {
            throw FixtureError.missingItemBaseType(id)
        }
        return base
    }

    public static func makeItem(
        _ baseID: String,
        id: String? = nil,
        rarity: Rarity = .basic,
        affixes: [ItemAffix] = [],
        affixPowers: [ItemAffixPower]? = nil,
    ) throws -> InventoryItem {
        let base = try baseType(baseID)
        return InventoryItem(
            id: id ?? base.id,
            baseType: base,
            rarity: rarity,
            displayName: base.name,
            affixes: affixes,
            affixPowers: affixPowers,
        )
    }
}
