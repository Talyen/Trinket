import TrinketContent
import TrinketCore

struct StoredInventoryItem: Codable {
    let id: String
    let templateID: String
    let baseTypeID: String
    let rarity: Rarity
    let displayName: String
    let isCorrupted: Bool
    let affixes: [StoredAffix]
    let powers: [ItemAffixPower]?

    init(_ item: InventoryItem) {
        id = item.id
        templateID = item.templateID
        baseTypeID = item.baseType.id
        rarity = item.rarity
        displayName = item.displayName
        isCorrupted = item.isCorrupted
        affixes = item.affixes.map(StoredAffix.init)
        powers = item.affixPowers
    }

    func resolve() throws -> InventoryItem {
        guard let base = GameContent.itemBaseType(matching: baseTypeID) else { throw StoredItemError.unknownBaseType }
        return InventoryItem(
            id: id, templateID: templateID, baseType: base, rarity: rarity, displayName: displayName,
            affixes: affixes.map(\.resolved), isCorrupted: isCorrupted, affixPowers: powers,
        )
    }

    struct StoredAffix: Codable {
        let id: String
        let title: String
        let description: String
        let keywords: Set<Keyword>
        let isCorrupted: Bool

        init(_ affix: ItemAffix) {
            id = affix.id
            title = affix.title
            description = affix.description
            keywords = affix.keywords
            isCorrupted = affix.isCorrupted
        }

        var resolved: ItemAffix {
            ItemAffix(id: id, title: title, description: description, keywords: keywords, isCorrupted: isCorrupted)
        }
    }
}

enum StoredItemError: Error {
    case unknownBaseType
}
