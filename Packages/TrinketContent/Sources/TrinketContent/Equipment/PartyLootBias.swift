import TrinketCore

/// Soft loot weights from the active pair's authored Talent affinities.
/// Matching either character gives 1.5x weight; a shared keyword gives 1.75x.
public struct PartyLootBias: Equatable, Sendable {
    private let favoredKeywords: Set<Keyword>
    private let sharedKeywords: Set<Keyword>

    public init() {
        favoredKeywords = []
        sharedKeywords = []
    }

    public init(roster: PlayerRosterState) {
        let hero = Set(roster.activeHero.affinityKeywords)
        let companion = Set(roster.activeCompanion.affinityKeywords)
        favoredKeywords = hero.union(companion)
        sharedKeywords = hero.intersection(companion)
    }

    var isEmpty: Bool {
        favoredKeywords.isEmpty
    }

    /// Integer quarters preserve the authored affix weights without rounding.
    func weight(for keywords: Set<Keyword>) -> Int {
        if !keywords.isDisjoint(with: sharedKeywords) {
            return 7
        }
        if !keywords.isDisjoint(with: favoredKeywords) {
            return 6
        }
        return 4
    }

    func select(
        from candidates: [InventoryItem],
        using random: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        precondition(!candidates.isEmpty, "Loot selection requires an eligible candidate.")
        guard !isEmpty else { return candidates[Int.random(in: candidates.indices, using: &random)] }
        let weights = candidates.map { weight(for: $0.keywords) }
        let index = WeightedLootSelection.index(in: weights, totalWeight: weights.reduce(0, +), weight: { $0 }, using: &random)
        return candidates[index ?? candidates.count - 1]
    }
}
