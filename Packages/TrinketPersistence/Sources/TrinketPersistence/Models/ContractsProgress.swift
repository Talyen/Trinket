import Foundation
import TrinketContent

public struct PlayerContractsState: Codable, Equatable, Sendable {
    public static let freshStart = Self()

    public private(set) var offers: [ContractOffer]
    public private(set) var refreshAvailable: Bool
    public private(set) var highestWonEncounterLevel: Int

    public init(offers: [ContractOffer] = [], refreshAvailable: Bool = false, highestWonEncounterLevel: Int = 0) {
        self.offers = offers
        self.refreshAvailable = refreshAvailable
        self.highestWonEncounterLevel = max(0, highestWonEncounterLevel)
    }

    private enum CodingKeys: String, CodingKey { case offers, refreshAvailable, highestWonEncounterLevel }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        offers = try values.decode([ContractOffer].self, forKey: .offers)
        refreshAvailable = try values.decodeIfPresent(Bool.self, forKey: .refreshAvailable) ?? false
        highestWonEncounterLevel = try max(0, values.decodeIfPresent(Int.self, forKey: .highestWonEncounterLevel) ?? 0)
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
        for difficulty in ContractDifficulty.allCases where offer(for: difficulty) == nil {
            let newOffer = makeOffer(difficulty, excludedEnemyIDs, eligibleModifiers)
            excludedEnemyIDs.insert(newOffer.enemyID)
            offers.append(newOffer)
        }
        offers = ContractDifficulty.allCases.compactMap { offer(for: $0) }
    }

    @discardableResult
    public mutating func refresh(
        eligibleModifiers: [RewardModifier] = RewardModifier.allCases,
        makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> Bool {
        guard refreshAvailable else { return false }
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

    mutating func reconcileRefreshAvailability(_ available: Bool) {
        refreshAvailable = available
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
                    && !ids.contains($0.id) && !enemyIDs.contains($0.enemyID)
                    && GameContent.enemy(matching: $0.enemyID)?.isBoss == difficulty.isBoss
            }) else { continue }
            ids.insert(offer.id)
            enemyIDs.insert(offer.enemyID)
            valid.append(offer)
        }
        return Self(offers: valid, refreshAvailable: refreshAvailable, highestWonEncounterLevel: highestWonEncounterLevel)
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
        do {
            return try JSONDecoder().decode(Self.self, from: data)
        } catch {
            // Offers are regenerable. Retain the independently earned quality
            // milestone when an otherwise readable payload has damaged offers.
            let fields: [String: Any]?
            do {
                fields = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            } catch {
                fields = nil
            }
            let level = fields?[CodingKeys.highestWonEncounterLevel.rawValue] as? Int ?? 0
            let refreshAvailable = fields?[CodingKeys.refreshAvailable.rawValue] as? Bool ?? false
            return Self(refreshAvailable: refreshAvailable, highestWonEncounterLevel: level)
        }
    }
}
