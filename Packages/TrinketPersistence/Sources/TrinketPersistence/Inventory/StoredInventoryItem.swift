import TrinketContent
import TrinketCore

/// Codable snapshot of an inventory item embedded in offer-payload blobs
/// (shop stock, mystery offers). Distinct from the normalized SwiftData
/// `InventoryItemModel` rows (durable store) and `CloudItemSnapshot` (cloud
/// wire): payloads must round-trip verbatim (rarity/powers preserved, unknown
/// base drops the offer) so a saved offer resolves identically on claim.
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

    /// Non-throwing by design: an unknown base drops the item (nil + log)
    /// instead of failing the enclosing shop/mystery payload. Callers filter
    /// homeless options and keep the surviving offers.
    func resolved() -> InventoryItem? {
        guard let base = ItemResolution.baseType(matching: baseTypeID, itemID: id) else { return nil }
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

        private enum CodingKeys: String, CodingKey {
            case id, title, description, keywords, isCorrupted
        }

        /// Lossy keyword decode: removed keywords are stripped instead of
        /// failing the whole offer payload (see `ItemResolution`).
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            description = try container.decode(String.self, forKey: .description)
            keywords = try ItemResolution.decodeKeywordSet(from: container, forKey: .keywords)
            isCorrupted = try container.decode(Bool.self, forKey: .isCorrupted)
        }

        var resolved: ItemAffix {
            ItemAffix(id: id, title: title, description: description, keywords: keywords, isCorrupted: isCorrupted)
        }
    }
}
