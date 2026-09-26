import TrinketContent
import TrinketCore

/// Codable snapshot of an inventory item embedded in offer-payload blobs
/// (shop stock, mystery offers) and CloudKit save snapshots. Unifies the
/// previously duplicate `CloudItemSnapshot` into a single canonical type.
///
/// Payloads round-trip verbatim (rarity/powers preserved, unknown base drops
/// the offer or item) so a saved offer resolves identically on claim and cloud
/// sync survives removed content gracefully. Supports decoding both `powers`
/// (legacy offer payloads) and `affixPowers` (cloud wire) keys for complete
/// backward compatibility.
public struct StoredInventoryItem: Codable, Equatable, Sendable {
    public let id: String
    public let templateID: String
    public let baseTypeID: String
    public let rarity: Rarity
    public let displayName: String
    public let isCorrupted: Bool
    public let affixes: [StoredAffix]
    public let powers: [ItemAffixPower]?

    public var affixPowers: [ItemAffixPower]? {
        powers
    }

    public typealias Affix = StoredAffix

    private enum CodingKeys: String, CodingKey {
        case id, templateID, baseTypeID, rarity, displayName, isCorrupted, affixes, powers, affixPowers
    }

    public init(_ item: InventoryItem) {
        id = item.id
        templateID = item.templateID
        baseTypeID = item.baseType.id
        rarity = item.rarity
        displayName = item.displayName
        isCorrupted = item.isCorrupted
        affixes = item.affixes.map(StoredAffix.init)
        powers = item.affixPowers
    }

    /// Lossy rarity and dual-key powers decode matching `ItemResolution`:
    /// an unknown rarity string falls back to `.basic` instead of failing
    /// the whole payload. Accepts either `powers` or `affixPowers` JSON keys.
    public init(from decoder: Decoder) throws {
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
            ?? container.decodeIfPresent([ItemAffixPower].self, forKey: .affixPowers)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(templateID, forKey: .templateID)
        try container.encode(baseTypeID, forKey: .baseTypeID)
        try container.encode(rarity, forKey: .rarity)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(isCorrupted, forKey: .isCorrupted)
        try container.encode(affixes, forKey: .affixes)
        try container.encodeIfPresent(powers, forKey: .powers)
        try container.encodeIfPresent(powers, forKey: .affixPowers)
    }

    /// Non-throwing by design: an unknown base drops the item (nil + log)
    /// instead of failing the enclosing payload. Callers filter homeless
    /// options and keep the surviving items.
    public func resolved() -> InventoryItem? {
        guard let base = ItemResolution.baseType(matching: baseTypeID, itemID: id) else { return nil }
        return InventoryItem(
            id: id, templateID: templateID, baseType: base, rarity: rarity, displayName: displayName,
            affixes: affixes.map(\.resolved), isCorrupted: isCorrupted, affixPowers: powers,
        )
    }

    /// Alias for `resolved()` ensuring backward compatibility with `CloudItemSnapshot.restored()`.
    public func restored() -> InventoryItem? {
        resolved()
    }

    public struct StoredAffix: Codable, Equatable, Sendable {
        public let id: String
        public let title: String
        public let description: String
        public let keywords: Set<Keyword>
        public let isCorrupted: Bool

        public init(id: String, title: String, description: String, keywords: Set<Keyword>, isCorrupted: Bool) {
            self.id = id
            self.title = title
            self.description = description
            self.keywords = keywords
            self.isCorrupted = isCorrupted
        }

        public init(_ affix: ItemAffix) {
            self.init(
                id: affix.id,
                title: affix.title,
                description: affix.description,
                keywords: affix.keywords,
                isCorrupted: affix.isCorrupted,
            )
        }

        private enum CodingKeys: String, CodingKey {
            case id, title, description, keywords, isCorrupted
        }

        /// Lossy keyword decode: removed keywords are stripped instead of
        /// failing the whole offer payload (see `ItemResolution`).
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            description = try container.decode(String.self, forKey: .description)
            keywords = try ItemResolution.decodeKeywordSet(from: container, forKey: .keywords)
            isCorrupted = try container.decode(Bool.self, forKey: .isCorrupted)
        }

        public var resolved: ItemAffix {
            ItemAffix(id: id, title: title, description: description, keywords: keywords, isCorrupted: isCorrupted)
        }
    }
}

public typealias CloudItemSnapshot = StoredInventoryItem
