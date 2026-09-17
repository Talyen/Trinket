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

    /// Lossy keyword decode shared by the JSON codecs. Unknown raw values
    /// (removed keywords) are dropped instead of failing the payload.
    static func keywordSet(from rawValues: [String]) -> Set<Keyword> {
        Set(rawValues.compactMap(Keyword.init(rawValue:)))
    }

    /// Failable single-keyword decode for unkeyed containers. Stored keyword
    /// sets encode as plain string arrays, so each element decodes from a
    /// single-value container; unknown strings become nil entries.
    struct FailableKeyword: Decodable {
        let value: Keyword?

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            value = Keyword(rawValue: raw)
        }
    }

    static func decodeKeywordSet<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K,
    ) throws -> Set<Keyword> {
        let values = try container.decode([FailableKeyword].self, forKey: key)
        return Set(values.compactMap(\.value))
    }

    static func decodeKeywordSet(_ decoder: Decoder) throws -> Set<Keyword> {
        let values = try [FailableKeyword](from: decoder)
        return Set(values.compactMap(\.value))
    }
}
