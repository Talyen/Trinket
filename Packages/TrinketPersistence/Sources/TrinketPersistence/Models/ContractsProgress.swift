import Foundation
import TrinketContent

public struct PlayerContractsState: Codable, Equatable, Sendable {
    public static let freshStart = Self()

    public private(set) var offers: [ContractOffer]
    public private(set) var refreshAvailable: Bool
    public private(set) var highestWonEncounterLevel: Int
    var completedOfferIDs: Set<String>?

    public init(offers: [ContractOffer] = [], refreshAvailable: Bool = false, highestWonEncounterLevel: Int = 0) {
        self.offers = offers
        self.refreshAvailable = refreshAvailable
        self.highestWonEncounterLevel = max(0, highestWonEncounterLevel)
        completedOfferIDs = []
    }

    private enum CodingKeys: String, CodingKey { case offers, refreshAvailable, highestWonEncounterLevel, completedOfferIDs }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Offers are regenerable. Recover independent milestones and receipts
        // even when another field is damaged, using the same typed codec.
        // PersistenceCheck: allow - Decode independent fields; corrupt data uses each field's recovery default.
        offers = (try? values.decode([ContractOffer].self, forKey: .offers)) ?? []
        completedOfferIDs = try? values.decode(Set<String>.self, forKey: .completedOfferIDs)
        refreshAvailable = (try? values.decode(Bool.self, forKey: .refreshAvailable)) ?? false
        highestWonEncounterLevel = max(0, (try? values.decode(Int.self, forKey: .highestWonEncounterLevel)) ?? 0)
    }

    public func offer(for difficulty: ContractDifficulty) -> ContractOffer? {
        offers.first { $0.difficulty == difficulty }
    }

    public mutating func ensureBoard(
        eligibleModifiers: [RewardModifier] = RewardModifier.allCases,
        makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) {
        self = sanitized()
        var excludedEnemyIDs = Set(offers.map(\.enemyID))
        let previous = offers
        offers = ContractDifficulty.allCases.map { difficulty in
            if let offer = previous.first(where: { $0.difficulty == difficulty }) {
                return offer
            }
            let newOffer = makeOffer(difficulty, excludedEnemyIDs, eligibleModifiers)
            excludedEnemyIDs.insert(newOffer.enemyID)
            return newOffer
        }
    }

    @discardableResult
    public mutating func refresh(
        eligibleModifiers: [RewardModifier] = RewardModifier.allCases,
        makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> Bool {
        guard refreshAvailable else { return false }
        completedOfferIDs = completedOfferIDs ?? []
        let previous = offers
        offers = []
        var excludedEnemyIDs = Set<String>()
        for difficulty in ContractDifficulty.allCases {
            var excluded = excludedEnemyIDs
            if let prior = previous.first(where: { $0.difficulty == difficulty }) {
                excluded.insert(prior.enemyID)
            }
            let newOffer = makeOffer(difficulty, excluded, eligibleModifiers)
            excludedEnemyIDs.insert(newOffer.enemyID)
            offers.append(newOffer)
        }
        refreshAvailable = false
        return true
    }

    public mutating func earnRefresh() {
        refreshAvailable = true
    }

    public mutating func recordVictory(encounterLevel: Int) {
        highestWonEncounterLevel = max(highestWonEncounterLevel, encounterLevel)
    }

    @discardableResult
    public mutating func replace(
        offerID: String,
        eligibleModifiers: [RewardModifier] = RewardModifier.allCases,
        makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> Bool {
        guard let index = offers.firstIndex(where: { $0.id == offerID }) else { return false }
        let replacement = makeOffer(offers[index].difficulty, Set(offers.map(\.enemyID)), eligibleModifiers)
        completedOfferIDs = (completedOfferIDs ?? []).union([offerID])
        offers[index] = replacement
        return true
    }

    func sanitized() -> Self {
        var ids: Set<String> = []
        var enemyIDs: Set<String> = []
        var valid: [ContractOffer] = []
        for difficulty in ContractDifficulty.allCases {
            guard let offer = offers.first(where: {
                $0.difficulty == difficulty && !$0.id.isEmpty
                    && !(completedOfferIDs ?? []).contains($0.id)
                    && !ids.contains($0.id) && !enemyIDs.contains($0.enemyID)
                    && GameContent.enemy(matching: $0.enemyID)?.isBoss == difficulty.isBoss
            }) else { continue }
            ids.insert(offer.id)
            enemyIDs.insert(offer.enemyID)
            valid.append(offer)
        }
        var repaired = Self(offers: valid, refreshAvailable: refreshAvailable, highestWonEncounterLevel: highestWonEncounterLevel)
        repaired.completedOfferIDs = completedOfferIDs
        return repaired
    }

    var encodedPayload: Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return try encoder.encode(self)
        } catch {
            preconditionFailure("Contract offers must be JSON encodable")
        }
    }

    static func decodePayload(_ data: Data?) -> Self {
        guard let data else { return .freshStart }
        // PersistenceCheck: allow - Decode only; malformed payloads recover below with unknown claim history.
        if let state = try? JSONDecoder().decode(Self.self, from: data) {
            return state
        }
        var recovered = Self()
        // Unreadable data cannot establish that claim history was tracked.
        recovered.completedOfferIDs = nil
        return recovered
    }
}
