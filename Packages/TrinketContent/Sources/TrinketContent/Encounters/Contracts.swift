import Foundation

public enum ContractDifficulty: String, Codable, CaseIterable, Sendable {
    case easy
    case standard
    case hard

    public var title: String {
        rawValue.capitalized
    }

    public var isBoss: Bool {
        self == .hard
    }
}

public struct ContractOffer: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let difficulty: ContractDifficulty
    public let enemyID: String
    public let rewardModifier: RewardModifier

    public init(
        id: String = UUID().uuidString,
        difficulty: ContractDifficulty,
        enemyID: String,
        rewardModifier: RewardModifier = .gold,
    ) {
        self.id = id
        self.difficulty = difficulty
        self.enemyID = enemyID
        self.rewardModifier = rewardModifier
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        difficulty = try values.decode(ContractDifficulty.self, forKey: .difficulty)
        enemyID = try values.decode(String.self, forKey: .enemyID)
        rewardModifier = try values.decodeIfPresent(RewardModifier.self, forKey: .rewardModifier) ?? .gold
    }
}

public enum ContractGenerator {
    public static func randomOffer(
        _ difficulty: ContractDifficulty,
        _ excludingEnemyIDs: Set<String>,
        _ eligibleModifiers: [RewardModifier],
    ) -> ContractOffer {
        var rng = SystemRandomNumberGenerator()
        return makeOffer(difficulty: difficulty, excludingEnemyIDs: excludingEnemyIDs, eligibleModifiers: eligibleModifiers, using: &rng)
    }

    public static func makeOffer(
        difficulty: ContractDifficulty,
        excludingEnemyIDs: Set<String> = [],
        eligibleModifiers: [RewardModifier] = RewardModifier.allCases,
        using rng: inout some RandomNumberGenerator,
        id: String = UUID().uuidString,
    ) -> ContractOffer {
        let pool = difficulty.isBoss ? GameContent.bossEnemies : GameContent.nonBossEnemies
        let alternatives = pool.filter { !excludingEnemyIDs.contains($0.id) }
        guard let enemy = (alternatives.isEmpty ? pool : alternatives).randomElement(using: &rng) else {
            preconditionFailure("Contracts require ordinary enemies and bosses in the catalog")
        }
        return ContractOffer(
            id: id, difficulty: difficulty, enemyID: enemy.id,
            rewardModifier: eligibleModifiers.randomElement(using: &rng) ?? .gold,
        )
    }
}
