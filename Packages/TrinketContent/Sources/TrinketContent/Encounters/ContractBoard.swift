import Foundation

/// Contract selection rules operate on pinned offers, independently of save storage.
/// Persistence supplies retirement history and owns refresh admission and claims.
public enum ContractBoard {
    public static func retainedOffers(_ offers: [ContractOffer], excluding retiredIDs: Set<String>) -> [ContractOffer] {
        guard !offers.isEmpty else { return [] }
        var ids: Set<String> = []
        var enemyIDs: Set<String> = []
        var valid: [ContractOffer] = []
        let byDifficulty = Dictionary(grouping: offers, by: \.difficulty)
        for difficulty in ContractDifficulty.allCases {
            guard let offer = byDifficulty[difficulty]?.first(where: {
                !$0.id.isEmpty
                    && !retiredIDs.contains($0.id)
                    && !ids.contains($0.id) && !enemyIDs.contains($0.enemyID)
                    && GameContent.enemy(matching: $0.enemyID)?.isBoss == difficulty.isBoss
            }) else { continue }
            ids.insert(offer.id)
            enemyIDs.insert(offer.enemyID)
            valid.append(offer)
        }
        return valid
    }

    public static func preparedOffers(
        _ offers: [ContractOffer], excluding retiredIDs: Set<String>,
        eligibleModifiers: [RewardModifier],
        makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> [ContractOffer] {
        let retained = retainedOffers(offers, excluding: retiredIDs)
        guard retained.count != ContractDifficulty.allCases.count else { return retained }
        var excludedEnemyIDs = Set(retained.lazy.map(\.enemyID))
        return ContractDifficulty.allCases.map { difficulty in
            if let offer = retained.first(where: { $0.difficulty == difficulty }) {
                return offer
            }
            let offer = makeOffer(difficulty, excludedEnemyIDs, eligibleModifiers)
            excludedEnemyIDs.insert(offer.enemyID)
            return offer
        }
    }

    public static func refreshedOffers(
        replacing previous: [ContractOffer], eligibleModifiers: [RewardModifier],
        makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> [ContractOffer] {
        var offers: [ContractOffer] = []
        var excludedEnemyIDs = Set<String>()
        for difficulty in ContractDifficulty.allCases {
            var excluded = excludedEnemyIDs
            if let prior = previous.first(where: { $0.difficulty == difficulty }) {
                excluded.insert(prior.enemyID)
            }
            let offer = makeOffer(difficulty, excluded, eligibleModifiers)
            excludedEnemyIDs.insert(offer.enemyID)
            offers.append(offer)
        }
        return offers
    }

    public static func replacingOffer(
        _ offerID: String, in offers: [ContractOffer], eligibleModifiers: [RewardModifier],
        makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> [ContractOffer]? {
        guard let index = offers.firstIndex(where: { $0.id == offerID }) else { return nil }
        var replaced = offers
        replaced[index] = makeOffer(offers[index].difficulty, Set(offers.lazy.map(\.enemyID)), eligibleModifiers)
        return replaced
    }
}
