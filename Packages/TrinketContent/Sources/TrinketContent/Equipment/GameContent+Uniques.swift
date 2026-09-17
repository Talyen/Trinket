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
            switch source {
            case let .catalog(id):
                guard let catalogDefinition = itemAffixDefinition(matching: id) else {
                    return nil
                }
                let max = catalogDefinition.astral.rolledMax()
                affixViews.append(ItemAffix(
                    id: catalogDefinition.id,
                    title: catalogDefinition.title,
                    description: max.description,
                    keywords: catalogDefinition.keywords,
                ))
                powers.append(max)
            case let .bespoke(bespoke):
                let max = bespoke.astral.rolledMax()
                affixViews.append(ItemAffix(
                    id: bespoke.id,
                    title: bespoke.title,
                    description: max.description,
                    keywords: bespoke.keywords,
                ))
                powers.append(max)
            }
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
