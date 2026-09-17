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

    private enum CodingKeys: String, CodingKey {
        case id, templateID, baseTypeID, rarity, displayName, isCorrupted, affixes, powers
    }

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

    /// Lossy rarity decode matching the documented `ItemResolution` policy:
    /// an unknown rarity string falls back to `.basic` instead of failing
    /// the whole shop/mystery payload.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        templateID = try container.decode(String.self, forKey: .templateID)
        baseTypeID = try container.decode(String.self, forKey: .baseTypeID)
        let rarityRawValue = try container.decode(String.self, forKey: .rarity)
        rarity = ItemResolution.rarity(matching: rarityRawValue)
        displayName = try container.decode(String.self, forKey: .displayName)
        isCorrupted = try container.decode(Bool.self, forKey: .isCorrupted)
        affixes = try container.decode([StoredAffix].self, forKey: .affixes)
        powers = try container.decodeIfPresent([ItemAffixPower].self, forKey: .powers)
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
