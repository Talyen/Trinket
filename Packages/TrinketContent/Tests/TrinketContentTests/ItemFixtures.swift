import Testing
import TrinketContent
import TrinketCore

enum ItemFixtures {
    static func baseType(_ id: String) throws -> ItemBaseType {
        try #require(GameContent.itemBaseType(matching: id))
    }

    static func makeItem(
        _ baseID: String,
        id: String? = nil,
        rarity: Rarity = .basic,
        affixes: [ItemAffix] = [],
        affixPowers: [ItemAffixPower]? = nil
    ) throws -> InventoryItem {
        let base = try baseType(baseID)
        return InventoryItem(
            id: id ?? base.id,
            baseType: base,
            rarity: rarity,
            displayName: base.name,
            affixes: affixes,
            affixPowers: affixPowers
        )
    }
}
