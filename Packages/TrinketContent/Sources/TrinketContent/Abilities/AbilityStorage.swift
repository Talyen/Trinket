import TrinketCore

/// Immutable definitions are shared through combat snapshots and nested automatic casts.
final class AbilityStorage: Hashable, Sendable {
    let id: String
    let name: String
    let tier: AbilityTier
    let operations: [AbilityOperation]
    let descriptionOverride: String?
    let outcomeBranches: [AbilityOutcomeBranch]?
    let conditionalOutcome: AbilityConditionalOutcome?
    let blockCost: Int
    let guaranteedCriticalCondition: DamageCondition?
    let criticalChanceBonus: Double
    let guaranteedCriticalIfEnemyBuffed: Bool
    let hasLeech: Bool
    let repeatsManaEmpowerment: Bool
    let stealsGold: Bool

    init(
        id: String,
        name: String,
        tier: AbilityTier,
        description: String? = nil,
        damageComponents: [DamageComponent] = [],
        effects: [Effect] = [],
        targetedEffects: [TargetedEffect]? = nil,
        outcomeBranches: [AbilityOutcomeBranch]? = nil,
        criticalChanceBonus: Double = 0,
        guaranteedCriticalIfEnemyBuffed: Bool = false,
        hasLeech: Bool = false,
        repeatsManaEmpowerment: Bool = false,
        stealsGold: Bool = false,
        operations: [AbilityOperation]? = nil,
        conditionalOutcome: AbilityConditionalOutcome? = nil,
        blockCost: Int = 0,
        guaranteedCriticalCondition: DamageCondition? = nil,
    ) {
        self.id = id
        self.name = name
        self.tier = tier
        self.operations = operations ?? (damageComponents.map(AbilityOperation.damage)
            + (targetedEffects ?? effects.map { TargetedEffect($0) }).map(AbilityOperation.effect))
        self.conditionalOutcome = conditionalOutcome
        self.blockCost = blockCost
        self.guaranteedCriticalCondition = guaranteedCriticalCondition
        descriptionOverride = description
        self.outcomeBranches = outcomeBranches
        self.criticalChanceBonus = criticalChanceBonus
        self.guaranteedCriticalIfEnemyBuffed = guaranteedCriticalIfEnemyBuffed
        self.hasLeech = hasLeech
        self.repeatsManaEmpowerment = repeatsManaEmpowerment
        self.stealsGold = stealsGold
    }

    static func == (lhs: AbilityStorage, rhs: AbilityStorage) -> Bool {
        lhs === rhs || (
            lhs.id == rhs.id
                && lhs.name == rhs.name
                && lhs.tier == rhs.tier
                && lhs.operations == rhs.operations
                && lhs.descriptionOverride == rhs.descriptionOverride
                && lhs.outcomeBranches == rhs.outcomeBranches
                && lhs.conditionalOutcome == rhs.conditionalOutcome
                && lhs.blockCost == rhs.blockCost
                && lhs.guaranteedCriticalCondition == rhs.guaranteedCriticalCondition
                && lhs.criticalChanceBonus == rhs.criticalChanceBonus
                && lhs.guaranteedCriticalIfEnemyBuffed == rhs.guaranteedCriticalIfEnemyBuffed
                && lhs.hasLeech == rhs.hasLeech
                && lhs.repeatsManaEmpowerment == rhs.repeatsManaEmpowerment
                && lhs.stealsGold == rhs.stealsGold
        )
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(tier)
        hasher.combine(operations)
        hasher.combine(descriptionOverride)
        hasher.combine(outcomeBranches)
        hasher.combine(conditionalOutcome)
        hasher.combine(blockCost)
        hasher.combine(guaranteedCriticalCondition)
        hasher.combine(criticalChanceBonus)
        hasher.combine(guaranteedCriticalIfEnemyBuffed)
        hasher.combine(hasLeech)
        hasher.combine(repeatsManaEmpowerment)
        hasher.combine(stealsGold)
    }
}
