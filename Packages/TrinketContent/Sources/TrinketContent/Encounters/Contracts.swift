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

    public init(id: String = UUID().uuidString, difficulty: ContractDifficulty, enemyID: String) {
        self.id = id
        self.difficulty = difficulty
        self.enemyID = enemyID
    }
}

public enum ContractGenerator {
    public static func makeOffer(
        difficulty: ContractDifficulty,
        excludingEnemyIDs: Set<String> = [],
        using rng: inout some RandomNumberGenerator,
    ) -> ContractOffer {
        let pool = GameContent.enemies.filter { $0.isBoss == difficulty.isBoss }
        let alternatives = pool.filter { !excludingEnemyIDs.contains($0.id) }
        guard let enemy = (alternatives.isEmpty ? pool : alternatives).randomElement(using: &rng) else {
            preconditionFailure("Contracts require ordinary enemies and bosses in the catalog")
        }
        return ContractOffer(difficulty: difficulty, enemyID: enemy.id)
    }
}
