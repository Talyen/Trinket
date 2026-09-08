import Foundation
import TrinketContent

public struct PlayerContractsState: Codable, Equatable, Sendable {
    public static let freshStart = Self()

    public private(set) var offers: [ContractOffer]

    public init(offers: [ContractOffer] = []) {
        self.offers = offers
    }

    public func offer(for difficulty: ContractDifficulty) -> ContractOffer? {
        offers.first { $0.difficulty == difficulty }
    }

    public mutating func ensureBoard() {
        self = sanitized()
        var rng = SystemRandomNumberGenerator()
        for difficulty in ContractDifficulty.allCases where offer(for: difficulty) == nil {
            offers.append(ContractGenerator.makeOffer(
                difficulty: difficulty,
                excludingEnemyIDs: Set(offers.map(\.enemyID)),
                using: &rng,
            ))
        }
        offers = ContractDifficulty.allCases.compactMap { offer(for: $0) }
    }

    public mutating func refresh() {
        let previous = offers
        offers = []
        var rng = SystemRandomNumberGenerator()
        for difficulty in ContractDifficulty.allCases {
            var excluded = Set(offers.map(\.enemyID))
            if let prior = previous.first(where: { $0.difficulty == difficulty }) {
                excluded.insert(prior.enemyID)
            }
            offers.append(ContractGenerator.makeOffer(
                difficulty: difficulty,
                excludingEnemyIDs: excluded,
                using: &rng,
            ))
        }
    }

    @discardableResult
    public mutating func replace(offerID: String) -> Bool {
        guard let index = offers.firstIndex(where: { $0.id == offerID }) else { return false }
        var rng = SystemRandomNumberGenerator()
        let replacement = ContractGenerator.makeOffer(
            difficulty: offers[index].difficulty,
            excludingEnemyIDs: Set(offers.map(\.enemyID)),
            using: &rng,
        )
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
        return Self(offers: valid)
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
            return .freshStart
        }
    }
}
