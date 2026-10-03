import Foundation
import TrinketContent
import TrinketCore

/// Single degradation policy shared by the three inventory item codecs
/// (SwiftData rows in `InventoryModel+ValueMapping`, offer blobs in
/// `StoredInventoryItem`, cloud wire in `CloudSaveSnapshot`):
///
/// - Unknown base type: drop the item (return nil) and log. Base families
///   are never removed in practice; when one is, losing the item beats
///   blocking the whole save, shop, or sync.
/// - Unknown keywords: strip the keyword, keep everything else. Matches the
///   SwiftData codec's long-standing `compactMap(Keyword.init)` behavior;
///   the JSON codecs below decode keyword sets through the same rule so one
///   removed keyword cannot brick a whole payload (synthesized
///   `Set<Keyword>` decoding would throw on the first unknown raw value).
/// - Unknown rarity strings: fall back to `.basic`.
/// - Stored affixes otherwise round-trip verbatim (title/description kept),
///   including bespoke unique signatures which live outside the generic
///   affix catalog and must never be stripped by a catalog lookup.
/// - Trinket catalog hits are authoritative: base/rarity/display/affixes come
///   from the catalog and stored affix powers are dropped (powers are
///   index-aligned with affixes, so keeping stored powers would describe the
///   wrong affixes). Offer/cloud codecs intentionally stay verbatim.
enum ItemResolution {
    static func baseType(matching id: String, itemID: String) -> ItemBaseType? {
        guard let base = GameContent.itemBaseType(matching: id) else {
            inventoryMappingLogger.error(
                "Dropping inventory item \(itemID, privacy: .public) with unknown base type \(id, privacy: .public)",
            )
            return nil
        }
        return base
    }

    static func rarity(matching rawValue: String) -> Rarity {
        Rarity(rawValue: rawValue) ?? .basic
    }

    static func decodeKeywordSet<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K,
    ) throws -> Set<Keyword> {
        let values = try container.decode([String].self, forKey: key)
        return Set(values.compactMap(Keyword.init(rawValue:)))
    }

    static func decodeKeywordSet(_ decoder: Decoder) throws -> Set<Keyword> {
        let values = try [String](from: decoder)
        return Set(values.compactMap(Keyword.init(rawValue:)))
    }

    /// Trinket-authoritative overwrite for the SwiftData codec. Returns the
    /// catalog item (preserving stored corruption) with powers dropped when
    /// the affix list is replaced, or nil when no overwrite applies.
    static func trinketAuthoritativeItem(
        persisted: InventoryItem,
        baseSlot: ItemSlot,
        templateID: String,
    ) -> InventoryItem? {
        guard baseSlot == .trinket,
              let authored = GameContent.itemTemplate(matching: templateID)
        else { return nil }
        return InventoryItem(
            id: persisted.id,
            templateID: authored.templateID,
            baseType: authored.baseType,
            rarity: authored.rarity,
            displayName: authored.displayName,
            affixes: authored.affixes,
            isCorrupted: persisted.isCorrupted,
            affixPowers: nil,
        )
    }
}
