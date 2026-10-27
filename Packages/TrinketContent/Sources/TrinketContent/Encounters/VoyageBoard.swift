import Foundation

/// Destination and reward rotation rules. Saved run admission, opaque payloads,
/// and completion/abandonment receipts remain owned by Persistence.
public enum VoyageBoard {
    public static func chapterIDs(access: ContentAccessPolicy) -> [String] {
        Array(GameContent.chapters.lazy.filter { access.allowsChapter($0.number) && VoyageCatalog.bossID(chapterID: $0.id) != nil }
            .map(\.id))
    }

    public static func preparedOffers(
        _ offers: [VoyageOffer], excluding retiredIDs: Set<String>,
        access: ContentAccessPolicy, eligibleModifiers: [RewardModifier],
        using rng: inout some RandomNumberGenerator,
    ) -> [VoyageOffer] {
        let allowed = chapterIDs(access: access)
        var prepared = offers
        if offers.count != VoyageDifficulty.allCases.count || Set(offers.lazy.map(\.chapterID)).count != VoyageDifficulty.allCases.count
            || offers.contains(where: { !allowed.contains($0.chapterID) }) {
            prepared = refreshedOffers(access: access, eligibleModifiers: eligibleModifiers, using: &rng)
        }
        for offer in prepared where retiredIDs.contains(offer.id) {
            prepared = replacingOffer(offer.id, in: prepared, access: access, eligibleModifiers: eligibleModifiers, using: &rng)
        }
        return prepared
    }

    public static func refreshedOffers(
        access: ContentAccessPolicy, eligibleModifiers: [RewardModifier],
        using rng: inout some RandomNumberGenerator,
    ) -> [VoyageOffer] {
        var chapters = chapterIDs(access: access).shuffled(using: &rng)
        let modifierCycle = eligibleModifiers.isEmpty ? [RewardModifier.gold] : eligibleModifiers.shuffled(using: &rng)
        var modifiers = modifierCycle
        return VoyageDifficulty.allCases.compactMap { difficulty in
            guard let chapterID = chapters.popLast() else { return nil }
            if modifiers.isEmpty {
                modifiers = modifierCycle
            }
            return offer(chapterID: chapterID, difficulty: difficulty, modifier: modifiers.popLast() ?? .gold, using: &rng)
        }
    }

    public static func replacingOffer(
        _ offerID: String, in offers: [VoyageOffer], access: ContentAccessPolicy,
        eligibleModifiers: [RewardModifier], using rng: inout some RandomNumberGenerator,
    ) -> [VoyageOffer] {
        guard let index = offers.firstIndex(where: { $0.id == offerID }) else { return offers }
        let previous = offers[index]
        let used = Set(offers.lazy.map(\.chapterID))
        let candidates = chapterIDs(access: access).filter { !used.contains($0) }
        let usedModifiers = Set(offers.enumerated().lazy.filter { $0.offset != index }.map(\.element.rewardModifier))
        let pool = eligibleModifiers.filter { !usedModifiers.contains($0) }
        let modifier = (pool.isEmpty ? eligibleModifiers : pool).randomElement(using: &rng) ?? .gold
        var replaced = offers
        replaced[index] = offer(
            chapterID: candidates.randomElement(using: &rng) ?? previous.chapterID,
            difficulty: previous.difficulty, modifier: modifier, using: &rng,
        )
        return replaced
    }

    private static func offer(
        chapterID: String, difficulty: VoyageDifficulty, modifier: RewardModifier,
        using rng: inout some RandomNumberGenerator,
    ) -> VoyageOffer {
        VoyageOffer(
            id: UUID().uuidString, chapterID: chapterID, difficulty: difficulty,
            seed: UInt64.random(in: .min ... .max, using: &rng), rewardModifier: modifier,
        )
    }
}
