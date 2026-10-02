import Synchronization
import TrinketCore

/// Immutable definitions are shared through combat snapshots and nested automatic casts.
final class AbilityStorage: Hashable, Sendable {
    /// Value equality, hashing, and combat transformations use this single payload.
    struct Definition: Hashable, Sendable {
        var id: String
        var name: String
        var tier: AbilityTier
        var operations: [AbilityOperation]
        var descriptionOverride: String?
        var outcomeBranches: [AbilityOutcomeBranch]?
        var conditionalOutcome: AbilityConditionalOutcome?
        var blockCost: Int
        var guaranteedCriticalCondition: DamageCondition?
        var criticalChanceBonus: Double
        var guaranteedCriticalIfEnemyBuffed: Bool
        var hasLeech: Bool
        var repeatsManaEmpowerment: Bool
        var stealsGold: Bool
    }

    let definition: Definition
    // Derived values belong to this immutable definition, not its ID.
    // Separate locks allow presentation resolution to request gameplay keywords and text.
    private let descriptionCache = Mutex<String?>(nil)
    private let keywordCache = Mutex<[Keyword]?>(nil)
    private let gameplayKeywordCache = Mutex(GameplayKeywords())

    private struct GameplayKeywords {
        var all: [Keyword]?
        var identity: [Keyword]?
    }

    init(_ definition: Definition) {
        self.definition = definition
    }

    func keywords(identityOnly: Bool, make: () -> [Keyword]) -> [Keyword] {
        gameplayKeywordCache.withLock { cached in
            if let keywords = identityOnly ? cached.identity : cached.all {
                return keywords
            }
            let keywords = make()
            if identityOnly {
                cached.identity = keywords
            } else {
                cached.all = keywords
            }
            return keywords
        }
    }

    func generatedDescription(for ability: Ability) -> String {
        descriptionCache.withLock { cached in
            if let cached {
                return cached
            }
            let description = AbilityDescriptionFormatter.format(ability)
            cached = description
            return description
        }
    }

    func presentationKeywords(for ability: Ability) -> [Keyword] {
        keywordCache.withLock { cached in
            if let cached {
                return cached
            }
            var keywords = ability.keywords
            for keyword in Keyword.referenced(in: ability.summary) where !keywords.contains(keyword) {
                keywords.append(keyword)
            }
            cached = keywords
            return keywords
        }
    }

    static func == (lhs: AbilityStorage, rhs: AbilityStorage) -> Bool {
        lhs === rhs || lhs.definition == rhs.definition
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(definition)
    }
}
