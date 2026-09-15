import TrinketContent
import TrinketCore

/// Shared inventory-item construction for tests.
///
/// This is the single home for item fixtures — including for
/// `TrinketContentTests`, which cannot depend on `TrinketTestSupport` without
/// a package cycle. `TrinketTestSupport` re-exports this type so existing
/// suites keep working; new code should import `TrinketContentTestSupport`
/// directly.
///
/// The helper does not run item generation: affixes default to empty and
/// stored powers to `nil`; callers can supply `affixes` and `affixPowers`
/// explicitly. Omitted stored powers exercise catalog fallback when affixes
/// are supplied. For items produced by the generator, use
/// `SaveTestSupport.makeGeneratedItem`. Default IDs are `"<base>-test"`,
/// so pass explicit `id`s when a test holds two items on the same base.
public enum ItemFixtures {
    public enum FixtureError: Error {
        case missingItemBaseType(String)
    }

    public static func baseType(_ id: String) throws -> ItemBaseType {
        guard let base = GameContent.itemBaseType(matching: id) else {
            throw FixtureError.missingItemBaseType(id)
        }
        return base
    }

    public static func makeBareItem(
        _ baseID: String,
        id: String? = nil,
        rarity: Rarity = .basic,
        affixes: [ItemAffix] = [],
        affixPowers: [ItemAffixPower]? = nil,
        isCorrupted: Bool = false,
    ) throws -> InventoryItem {
        let base = try baseType(baseID)
        return InventoryItem(
            id: id ?? "\(base.id)-test",
            baseType: base,
            rarity: rarity,
            displayName: base.name,
            affixes: affixes,
            isCorrupted: isCorrupted,
            affixPowers: affixPowers,
        )
    }
}
