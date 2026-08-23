import Foundation
import TrinketCore

public extension GameContent {
    /// Authored Unique definitions before resolution against base types.
    static let uniqueDefinitions: [UniqueItemDefinition] = UniqueCatalog.definitions

    /// Authored Unique items resolved against their base types with exact pinned powers.
    static let uniqueItems: [InventoryItem] = UniqueCatalog.definitions.compactMap(resolve)

    static let uniquesByID: [String: InventoryItem] = Dictionary(
        uniqueKeysWithValues: uniqueItems.map { ($0.id, $0) }
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
                affixViews.append(catalogDefinition.resolved(for: .astral))
                powers.append(catalogDefinition.astral)
            case let .bespoke(bespoke):
                affixViews.append(ItemAffix(
                    id: bespoke.id,
                    title: bespoke.title,
                    description: bespoke.astral.description,
                    keywords: bespoke.keywords
                ))
                powers.append(bespoke.astral)
            }
        }
        return InventoryItem(
            id: definition.id,
            templateID: definition.id,
            baseType: baseType,
            rarity: .unique,
            displayName: definition.displayName,
            affixes: affixViews,
            affixPowers: powers
        )
    }
}
