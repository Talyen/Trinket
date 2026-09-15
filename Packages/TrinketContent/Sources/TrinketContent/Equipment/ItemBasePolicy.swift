import Foundation
import TrinketCore

/// Single home for item base-type selection.
///
/// Two confirmed policies, two callers; the names record which caller uses
/// which and why they differ:
///
/// - `uniformFallbackBase` — live loot (`ItemRewardGenerator`): uniform draw
///   over non-trinket bases, falling back to the full set when the keyword
///   bias matches nothing. Loot rarity and affix counts are rolled per reward
///   (`ItemGenerator.affixCount`), so base odds stay level-independent.
/// - `maxAffinityBase` — themed sims and enemy loadouts
///   (`ThemedGearGenerator`): rank by keyword overlap, draw uniformly among
///   the top tier. Sims pin `fixedAffixCount` per tier instead of rolling,
///   so sim gear and live loot intentionally follow different regimes.
enum ItemBasePolicy {
    static func uniformFallbackBase(
        from baseTypes: [ItemBaseType],
        keywordBias: Set<Keyword>,
        fallback: ItemBaseType?,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemBaseType {
        let normalBases = fallback.map { [$0] } ?? baseTypes.filter { $0.slot != .trinket }
        precondition(!normalBases.isEmpty, "Item rewards require at least one non-Trinket base type.")
        let biasedBases = keywordBias.isEmpty
            ? normalBases
            : normalBases.filter { !$0.keywordAffinities.isDisjoint(with: keywordBias) }
        let pool = biasedBases.isEmpty ? normalBases : biasedBases
        return pool.randomElement(using: &randomNumberGenerator) ?? pool[0]
    }

    static func maxAffinityBase(
        from candidates: [ItemBaseType],
        keywordBias: Set<Keyword>,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemBaseType? {
        guard !candidates.isEmpty else { return nil }
        let ranked = candidates.map { baseType -> (ItemBaseType, Int) in
            let overlap = baseType.keywordAffinities.intersection(keywordBias).count
            return (baseType, overlap)
        }
        let maxOverlap = ranked.map(\.1).max() ?? 0
        let topCandidates = ranked.filter { $0.1 == maxOverlap }.map(\.0)
        return topCandidates.randomElement(using: &randomNumberGenerator)
    }
}
