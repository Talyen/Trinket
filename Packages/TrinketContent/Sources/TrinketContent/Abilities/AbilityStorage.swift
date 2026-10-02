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

    init(_ definition: Definition) {
        self.definition = definition
    }

    static func == (lhs: AbilityStorage, rhs: AbilityStorage) -> Bool {
        lhs === rhs || lhs.definition == rhs.definition
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(definition)
    }
}
