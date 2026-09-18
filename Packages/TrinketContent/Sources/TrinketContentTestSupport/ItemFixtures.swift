import TrinketContent
import TrinketCore

/// Shared inventory-item construction for tests.
///
/// This is the single home for item fixtures. It lives in this package's
/// `TrinketContentTestSupport` target (rather than a separate package) so
/// `TrinketContentTests` can use it without a package cycle.
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

    /// Affix definitions eligible for a base type. Single home for the
    /// predicate so catalog and generator tests cannot drift apart.
    public static func eligibleAffixes(forBaseType baseType: ItemBaseType) -> [ItemAffixDefinition] {
        GameContent.itemAffixDefinitions.filter { $0.isEligible(for: baseType) }
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
