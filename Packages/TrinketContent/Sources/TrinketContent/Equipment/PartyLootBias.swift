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

    private func weight(for item: InventoryItem) -> Int {
        if sharedKeywords.isEmpty {
            return item.affixes.contains { !$0.keywords.isDisjoint(with: favoredKeywords) } ? 6 : 4
        }
        var favored = false
        for affix in item.affixes {
            if !affix.keywords.isDisjoint(with: sharedKeywords) {
                return 7
            }
            if !favored, !affix.keywords.isDisjoint(with: favoredKeywords) {
                favored = true
            }
        }
        return favored ? 6 : 4
    }

    func select(
        from candidates: [InventoryItem],
        using random: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        precondition(!candidates.isEmpty, "Loot selection requires an eligible candidate.")
        guard !isEmpty else { return candidates[Int.random(in: candidates.indices, using: &random)] }
        var totalWeight = 0
        let weights = candidates.map { candidate in
            let weight = weight(for: candidate)
            totalWeight += weight
            return weight
        }
        let index = WeightedLootSelection.index(in: weights, totalWeight: totalWeight, weight: { $0 }, using: &random)
        return candidates[index ?? candidates.count - 1]
    }
}
