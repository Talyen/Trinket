import Foundation
import TrinketCore

public extension GameContent {
    static let uniqueDefinitions: [UniqueItemDefinition] = UniqueCatalog.definitions

    static let uniqueItems: [InventoryItem] = UniqueCatalog.definitions.compactMap(resolve)

    private static let uniquesByID: [String: InventoryItem] = Dictionary(
        uniqueKeysWithValues: uniqueItems.map { ($0.id, $0) },
    )

    static func unique(matching id: String) -> InventoryItem? {
        uniquesByID[id]
    }

    private static func resolve(_ definition: UniqueItemDefinition) -> InventoryItem? {
        guard let baseType = itemBaseType(matching: definition.baseTypeID) else {
            return nil
        }
        var affixViews: [ItemAffix] = []
        var powers: [ItemAffixPower] = []
        for source in definition.affixes {
            let affix: ItemAffixDefinition
            switch source {
            case let .catalog(id):
                guard let catalog = itemAffixDefinition(matching: id) else {
                    return nil
                }
                affix = catalog
            case let .bespoke(bespoke):
                affix = bespoke
            }
            let power = affix.astral.rolledMax()
            affixViews.append(ItemAffix(
                id: affix.id, title: affix.title, description: power.description, keywords: affix.keywords,
            ))
            powers.append(power)
        }
        return InventoryItem(
            id: definition.id,
            templateID: definition.id,
            baseType: baseType,
            rarity: .unique,
            displayName: definition.displayName,
            affixes: affixViews,
            affixPowers: powers,
        )
    }
}
